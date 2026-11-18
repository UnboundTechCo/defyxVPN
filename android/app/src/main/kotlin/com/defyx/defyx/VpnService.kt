package de.unboundtech.defyxvpn

import android.Android
import android.SocketProtector
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray

class DefyxVpnService : VpnService() {
    companion object {
        private const val TAG = "DefyxVpnService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "defyx_vpn_channel"
        private const val INSTANCE_TIMEOUT_MS = 5_000L
        private const val CORE_STOP_TIMEOUT_MS = 10_000L

        @Volatile private lateinit var instance: DefyxVpnService
        fun getInstance(): DefyxVpnService = instance

        // Completes with the instance the system is running. A stopped
        // service leaves `instance` pointing at a destroyed object, on which
        // startForeground does nothing.
        @Volatile private var running = CompletableDeferred<DefyxVpnService>()

        /** Starts the service if it is not running and returns the live instance. */
        suspend fun awaitRunning(context: Context): DefyxVpnService {
            context.startService(Intent(context, DefyxVpnService::class.java))
            return withTimeout(INSTANCE_TIMEOUT_MS) { running.await() }
        }

        // Starting and stopping the tunnel run one at a time, so a disconnect
        // during a connect cannot leave an interface that nothing reads.
        private val lifecycle = Mutex()
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

        @Volatile private var vpnInterface: ParcelFileDescriptor? = null
        @Volatile private var listener: ((String) -> Unit)? = null
        @Volatile private var isVpnConnected = false
        private var connectionMethod: String? = ""

        fun setVpnStatusListener(l: (String) -> Unit) {
            listener = l
        }
        fun clearVpnStatusListener(l: (String) -> Unit) {
            if (listener === l) listener = null
        }
        fun notifyVpnStatus(status: String) {
            listener?.invoke(status)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        AppProxy.install()
        createNotificationChannel()
        if (!running.complete(this)) {
            running = CompletableDeferred(this)
        }
    }

    override fun onDestroy() {
        running = CompletableDeferred()
        // The system destroys the service on revoke and when it is stopped.
        // The interface goes here; the core stops in the background because
        // it can take long and this runs on the main thread.
        if (vpnInterface != null || isVpnConnected) {
            releaseTunnel()
            scope.launch { stopCore() }
            notifyVpnStatus("disconnected")
        }
        super.onDestroy()
        log("VPN Service Destroyed")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "ACTION_DISCONNECT_VPN" -> {
                stopVpn()
            }
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                                    CHANNEL_ID,
                                    "DefyxVPN Service",
                                    NotificationManager.IMPORTANCE_LOW
                            )
                            .apply {
                                description = "Keep DefyxVPN running in background"
                                setShowBadge(false)
                            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .createNotificationChannel(channel)
        }
    }

    // Returns whether the service became a foreground service. The type must
    // match the manifest; Android lists VPN apps under systemExempted.
    private fun startAsForeground(title: String, contentText: String): Boolean {
        val notification = buildNotification(title, contentText, isVpnConnected)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground: ${e.message}", e)
            false
        }
    }

    private fun updateNotification(title: String, contentText: String) {
        val notification = buildNotification(title, contentText, isVpnConnected)
        val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(
            title: String,
            contentText: String,
            isConnected: Boolean
    ): Notification {
        val intent =
                Intent(this, MainActivity::class.java).apply {
                    putExtra("unique_id", System.currentTimeMillis())
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }

        val actionIntent =
                Intent(this, DefyxVpnService::class.java).apply {
                    action = if (isConnected) "ACTION_DISCONNECT_VPN" else "ACTION_CONNECT_VPN"
                }

        val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }

        val timestamp = System.currentTimeMillis().toInt()
        val pendingIntent = PendingIntent.getActivity(this, timestamp, intent, flags)
        val actionPendingIntent = PendingIntent.getService(this, timestamp + 1, actionIntent, flags)

        val actionText = "Disconnect"
        val actionIcon = android.R.drawable.ic_menu_close_clear_cancel

        val builder =
                NotificationCompat.Builder(this, CHANNEL_ID)
                        .setContentTitle(title)
                        .setContentText(contentText)
                        .setSmallIcon(android.R.drawable.ic_lock_lock)
                        .setContentIntent(pendingIntent)
                        .setOngoing(true)
                        .setAutoCancel(false)
                        .setCategory(NotificationCompat.CATEGORY_SERVICE)
                        .setPriority(NotificationCompat.PRIORITY_LOW)
                        .setForegroundServiceBehavior(
                                NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE
                        )
        if (isConnected) {
            builder.addAction(actionIcon, actionText, actionPendingIntent)
        }

        return builder.build()
    }

    fun startVpn(
            context: Context,
            splitMode: String,
            splitRules: String,
            splitApps: String,
            onResult: (Boolean) -> Unit = {}
    ) {
        scope.launch {
            val started =
                    lifecycle.withLock { openTunnel(context, splitMode, splitRules, splitApps) }
            onResult(started)
        }
    }

    // Answers true only once the interface exists and the tunnel reads it.
    private fun openTunnel(
            context: Context,
            splitMode: String,
            splitRules: String,
            splitApps: String
    ): Boolean {
        Log.d(TAG, "startVpn called")
        try {
            notifyVpnStatus("connecting")
            if (!startAsForeground("DefyxVPN", "Connecting...")) {
                failTunnel()
                return false
            }
            logPrivateDns()

            val builder =
                    Builder()
                            .setSession("DefyxVPN")
                            .addAddress("172.18.0.1", 30)
                            .addAddress("fdfe:dcba:9876::1", 126)
                            .addRoute("0.0.0.0", 0)
                            .addRoute("::", 0)
                            .addDnsServer("172.18.0.2")
                            .setMtu(1500)
                            .setBlocking(false)

            applySplitApps(builder, context.packageName, splitMode, splitApps)

            releaseTunnel()
            vpnInterface = builder.establish()

            val fd = vpnInterface?.fd ?: -1
            if (fd <= 0) {
                Log.e(TAG, "Failed to establish tun interface")
                failTunnel()
                return false
            }

            Android.setSocketProtector(
                    object : SocketProtector {
                        override fun protect(fileDescriptor: Int): Boolean =
                                this@DefyxVpnService.protect(fileDescriptor)
                    }
            )
            Android.setSplitTunnel(splitMode, splitRules, splitApps)
            if (!Android.startTunnel(fd.toLong())) {
                Log.e(TAG, "Tunnel start failed")
                failTunnel()
                return false
            }

            isVpnConnected = true
            AppProxy.setEnabled(true)
            updateNotification("DefyxVPN", "Connected by $connectionMethod")
            notifyVpnStatus("connected")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "startVpn failed: ${e.message}", e)
            failTunnel()
            return false
        }
    }

    private fun failTunnel() {
        releaseTunnel()
        updateNotification("DefyxVPN", "Connection failed")
        notifyVpnStatus("disconnected")
    }

    // An established interface that no tunnel reads from takes all traffic of
    // the device and drops it, so it is closed as soon as the tunnel fails.
    // The tunnel holds its own copy of the descriptor, so the interface only
    // goes away once both are closed. Safe to call when nothing is open.
    private fun releaseTunnel() {
        AppProxy.setEnabled(false)
        try {
            Android.stopTunnel()
        } catch (_: Exception) {}
        try {
            vpnInterface?.close()
        } catch (_: Exception) {}
        vpnInterface = null
        isVpnConnected = false
    }

    // Stopping the core waits for its transports to shut down, which can take
    // long. It runs apart, so a stuck core cannot hold up the disconnect.
    private suspend fun stopCore(): Boolean {
        val stopping = scope.async {
            try {
                Android.stopVPN()
                true
            } catch (e: Exception) {
                log("Error stopping VPN: ${e.message}")
                false
            }
        }
        val stopped = withTimeoutOrNull(CORE_STOP_TIMEOUT_MS) { stopping.await() }
        if (stopped == null) {
            log("Core still stopping after ${CORE_STOP_TIMEOUT_MS / 1000}s, not waiting for it")
        }
        return stopped == true
    }

    // A Private DNS hostname makes Android send all DNS to that server through
    // the VPN. Servers that only accept local addresses then fail, so the
    // setting is logged to explain such reports.
    private fun logPrivateDns() {
        val server = PrivateDns.host(this) ?: return
        log("Private DNS is set to $server, DNS of other apps goes to it through the VPN")
    }

    private fun applySplitApps(builder: Builder, ownPackage: String, mode: String, apps: String) {
        val packages =
                try {
                    val array = JSONArray(apps)
                    (0 until array.length())
                            .map { array.optString(it) }
                            .filter { it.isNotEmpty() && it != ownPackage && isInstalled(it) }
                            .distinct()
                } catch (_: Exception) {
                    emptyList()
                }

        if (mode == "only" && packages.isNotEmpty()) {
            for (app in packages) {
                try {
                    builder.addAllowedApplication(app)
                } catch (_: Exception) {}
            }
            return
        }

        // The core runs in this app and dials its servers without protect(),
        // so its own traffic must stay outside the tunnel or it would loop
        // back into itself. The app's other traffic is sent to the core's
        // proxy instead, see AppProxy and AppTraffic.
        try {
            builder.addDisallowedApplication(ownPackage)
        } catch (_: Exception) {}

        if (mode == "exclude") {
            for (app in packages) {
                try {
                    builder.addDisallowedApplication(app)
                } catch (_: Exception) {}
            }
        }
    }

    private fun isInstalled(packageName: String): Boolean =
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.ApplicationInfoFlags.of(0)
                    )
                } else {
                    @Suppress("DEPRECATION") packageManager.getApplicationInfo(packageName, 0)
                }
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }

    /**
     * Closes the tunnel, then stops the core. [onDone] runs once the
     * interface is gone and the core has stopped or [CORE_STOP_TIMEOUT_MS]
     * passed, with whether the core stopped in time.
     */
    fun stopVpn(onDone: (Boolean) -> Unit = {}) {
        scope.launch {
            val stopped =
                    lifecycle.withLock {
                        notifyVpnStatus("disconnecting")
                        // The interface goes first: it carries the device's
                        // traffic and closes at once.
                        releaseTunnel()
                        val coreStopped = stopCore()
                        withContext(Dispatchers.Main) {
                            stopForeground(STOP_FOREGROUND_REMOVE)
                            val notificationManager =
                                    getSystemService(Context.NOTIFICATION_SERVICE) as
                                            NotificationManager
                            notificationManager.cancel(NOTIFICATION_ID)
                            // The next connect starts it again, see awaitRunning.
                            stopSelf()
                        }
                        notifyVpnStatus("disconnected")
                        coreStopped
                    }
            onDone(stopped)
        }
    }

    fun measurePing(): Long {
        return try {
            Android.measurePing()
        } catch (e: Exception) {
            log("Measure Ping failed: ${e.message}")
            0
        }
    }

    fun connectVPN(
            cacheDir: String,
            flowLine: String,
            pattern: String,
            deepScan: Boolean,
            healthCheck: Boolean
    ) {
        scope.launch {
            try {
                Android.startVPN(cacheDir, flowLine, pattern, deepScan, healthCheck)
            } catch (e: Exception) {
                log("Start VPN failed: ${e.message}")
            }
        }
    }
    fun disconnectVPN() {
        try {
            Android.stopVPN()
        } catch (e: Exception) {
            log("Stop VPN failed: ${e.message}")
        }
    }

    fun getFlag(): String {
        return try {
            Android.getFlag()
        } catch (e: Exception) {
            log("Get Flag failed: ${e.message}")
            ""
        }
    }

    fun setAsnName() {
        try {
            Android.setAsnName()
        } catch (e: Exception) {
            log("Set ASN Name failed: ${e.message}")
        }
    }

    fun setTimezone(timezone: Float) {
        try {
            Android.setTimeZone(timezone)
        } catch (e: Exception) {
            log("Set Local Timezone failed: ${e.message}")
        }
    }

    fun getFlowLine(isTest: Boolean, token: String): String {
        return try {
            Android.getFlowLine(isTest, token)
        } catch (e: Exception) {
            log("Get Flow Line failed: ${e.message}")
            ""
        }
    }

    fun getCachedFlowLine(): String {
        return try {
            Android.getCachedFlowLine()
        } catch (e: Exception) {
            log("Get Cached Flow Line failed: ${e.message}")
            ""
        }
    }

    fun decodeAndVerifyFlowline(flowLine: String): String {
        return try {
            Android.decodeAndVerifyFlowline(flowLine)
        } catch (e: Exception) {
            log("Decode and Verify Flowline failed: ${e.message}")
            ""
        }
    }

    fun log(message: String) {
        try {
            Android.log(message)
        } catch (e: Exception) {
            Log.e("Get Flow Line", "Get Flow Line failed: ${e.message}", e)
        }
    }

    fun getVpnStatus(): String = if (isVpnConnected) "connected" else "disconnected"

    fun isTunnelRunning(): Boolean = isVpnConnected

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed")
    }

    override fun onRevoke() {
        super.onRevoke()
        Log.d("VPN_SERVICE", "Revoked")
        stopVpn()
    }

    fun setConnectionMethod(method: String) {
        connectionMethod = method
    }

    fun setCacheDir(cacheDir: String) {
        try {
            val directory = File(cacheDir)
            if (!directory.exists()) {
                directory.mkdirs()
            }
            Android.setCacheDir(cacheDir)
        } catch (e: Exception) {
            log("Set Cache Dir failed: ${e.message}")
        }
    }

    fun login(email: String, password: String): String {
        return try {
            Android.login(email, password)
        } catch (e: Exception) {
            log("Login failed: ${e.message}")
            ""
        }
    }

    fun loginByCode(code: String): String {
        return try {
            Android.loginByCode(code)
        } catch (e: Exception) {
            log("Login by code failed: ${e.message}")
            ""
        }
    }
}
