package de.unboundtech.defyxvpn

import android.Android
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.edit
import java.io.File
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

private const val VPN_OPERATION_TIMEOUT_MS = 30_000L

class DefyxVpnService : VpnService() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        private const val TAG = "DefyxVpnService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "defyx_vpn_channel"
        @Volatile private lateinit var instance: DefyxVpnService
        fun getInstance(): DefyxVpnService = instance
        private var vpnInterface: ParcelFileDescriptor? = null
        private var listener: ((String) -> Unit)? = null
        private val operationMutex = Mutex()
        @Volatile private var tunnelFd = -1
        @Volatile private var tunnelFdPassedToCore = false
        @Volatile private var isServiceRunning = false
        @Volatile private var isVpnConnected = false
        private var connectionMethod: String? = ""

        private enum class VpnState {
            DISCONNECTED,
            CONNECTING,
            CONNECTED,
            DISCONNECTING
        }

        private var vpnState = VpnState.DISCONNECTED

        fun setVpnStatusListener(l: ((String) -> Unit)?) {
            listener = l
        }
        fun notifyVpnStatus(status: String) {
            listener?.invoke(status)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        if (getSharedPreferences("defyx_vpn_prefs", Context.MODE_PRIVATE)
                        .getBoolean("vpn_running", false)) {
            log("Clearing stale VPN running state after service restart")
            saveVpnState(false)
        }
    }

    override fun onDestroy() {
        log("VPN Service Destroyed")
        try {
            runBlocking(Dispatchers.IO) { disconnectVpnAndWait() }
        } catch (e: Throwable) {
            log("Service destroy cleanup timed out: ${e.message}")
        }
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "ACTION_DISCONNECT_VPN" -> {
                disconnectVpn()
            }
        }
        return START_STICKY
    }

    private suspend fun disconnectVpnAndWait() {
        operationMutex.withLock {
            if (vpnState == VpnState.DISCONNECTED) {
                return
            }

            vpnState = VpnState.DISCONNECTING
            notifyVpnStatus("disconnecting")
            try {
                withTimeout(VPN_OPERATION_TIMEOUT_MS) {
                    cleanupVpn("disconnected")
                }
            } catch (e: Throwable) {
                log("Error stopping VPN: ${e.message}")
                throw e
            }
        }
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

    private fun startAsForeground(title: String, contentText: String) {
        val notification = buildNotification(title, contentText, isVpnConnected)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to promote VPN service to foreground", e)
                throw ForegroundPromotionException(e)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isServiceRunning = true
    }

    private class ForegroundPromotionException(cause: Throwable) :
            IllegalStateException("Failed to promote VPN service to foreground", cause)

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
            onConnected: () -> Unit = {},
            onFailure: (Throwable) -> Unit = {}
        ) {
        serviceScope.launch {
            operationMutex.withLock {
                if (vpnState == VpnState.CONNECTED) {
                    onConnected()
                    return@withLock
                }
                if (vpnState == VpnState.CONNECTING || vpnState == VpnState.DISCONNECTING) {
                    onFailure(IllegalStateException("VPN operation already in progress"))
                    return@withLock
                }

                vpnState = VpnState.CONNECTING
                notifyVpnStatus("connecting")
                try {
                    withTimeout(VPN_OPERATION_TIMEOUT_MS) {
                        startAsForeground("DefyxVPN", "Connecting...")

                        val builder =
                                Builder()
                                        .setSession("DefyxVPN")
                                        .addAddress("10.0.0.2", 32)
                                        .addRoute("0.0.0.0", 0)
                                        .addDnsServer("1.1.1.1")
                                        .allowFamily(android.system.OsConstants.AF_INET)
                                        .setMtu(1500)
                                        .setBlocking(true)
                                        .allowBypass()

                        try {
                            builder.addDisallowedApplication(context.packageName)
                        } catch (_: Exception) {}
                
                        vpnInterface?.close()
                        vpnInterface = builder.establish()
                        Log.d(TAG, "vpnInterface: $vpnInterface")

                        if (vpnInterface == null) {
                            throw IllegalStateException("VPN interface could not be established")
                        }

                        val fd = vpnInterface?.detachFd() ?: -1
                        Log.d(TAG, "Tunnel fd: $fd")

                        if (fd <= 0) {
                            throw IllegalStateException("VPN tunnel descriptor is invalid")
                        }

                        tunnelFd = fd
                        vpnInterface = null
                        Android.startT2S(tunnelFd.toLong(), "127.0.0.1:5000")
                        tunnelFdPassedToCore = true
                        isVpnConnected = true
                        vpnState = VpnState.CONNECTED
                        saveVpnState(true)
                        updateNotification("DefyxVPN", "Connected by " + connectionMethod)
                        notifyVpnStatus("connected")
                    }
                    onConnected()
                } catch (e: Throwable) {
                    Log.e(TAG, "startVpn failed: ${e.message}", e)
                    withContext(NonCancellable) { cleanupVpn("disconnected") }
                    onFailure(e)
                }
            }
        }
    }

    private fun disconnectVpn(
            onComplete: () -> Unit = {},
            onFailure: (Throwable) -> Unit = {}
    ) {
        serviceScope.launch {
            try {
                disconnectVpnAndWait()
                onComplete()
            } catch (e: Throwable) {
                log("Error stopping VPN: ${e.message}")
                onFailure(e)
            }
        }
    }

    private suspend fun cleanupVpn(status: String) {
        val shouldNotify = vpnState != VpnState.DISCONNECTED
        try {
            try {
                Android.stopVPN()
            } catch (e: Exception) {
                log("Stop VPN failed during cleanup: ${e.message}")
            }

            try {
                stopTun2Socks()
            } catch (e: Exception) {
                log("Stop T2S failed during cleanup: ${e.message}")
            }

            try {
                vpnInterface?.close()
            } catch (e: Exception) {
                log("Close VPN interface failed during cleanup: ${e.message}")
            }
        } finally {
            vpnInterface = null
            if (tunnelFd > 0 && !tunnelFdPassedToCore) {
                try {
                    ParcelFileDescriptor.adoptFd(tunnelFd).close()
                } catch (e: Exception) {
                    log("Close detached VPN descriptor failed during cleanup: ${e.message}")
                }
            }
            tunnelFd = -1
            tunnelFdPassedToCore = false
            isVpnConnected = false
            isServiceRunning = false
            connectionMethod = ""
            vpnState = VpnState.DISCONNECTED

            try {
                saveVpnState(false)
            } catch (e: Exception) {
                log("Persist disconnected state failed: ${e.message}")
            }

            if (shouldNotify) {
                notifyVpnStatus(status)
            }
            try {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    val notificationManager =
                        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancel(NOTIFICATION_ID)
            } catch (e: Exception) {
                log("Remove VPN notification failed: ${e.message}")
            }
        }
    }

    fun stopVpn(onComplete: () -> Unit = {}, onFailure: (Throwable) -> Unit = {}) {
        disconnectVpn(onComplete, onFailure)
    }

    fun stopTun2Socks() {
        try {
            Android.stopT2S()
        } catch (e: Exception) {
            log("Stop T2S failed: ${e.message}")
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
        CoroutineScope(Dispatchers.IO).launch {
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

    fun isTunnelRunning(): Boolean = tunnelFd > 0

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed")
        try {
            runBlocking(Dispatchers.IO) { disconnectVpnAndWait() }
        } catch (e: Throwable) {
            log("Task removal cleanup timed out: ${e.message}")
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onRevoke() {
        Log.d("VPN_SERVICE", "Revoked")
        try {
            runBlocking(Dispatchers.IO) { disconnectVpnAndWait() }
        } catch (e: Throwable) {
            log("Revoke cleanup timed out: ${e.message}")
        }
        super.onRevoke()
    }

    private fun saveVpnState(isRunning: Boolean) {
        applicationContext.getSharedPreferences("defyx_vpn_prefs", Context.MODE_PRIVATE).edit {
            putBoolean("vpn_running", isRunning)
        }
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
