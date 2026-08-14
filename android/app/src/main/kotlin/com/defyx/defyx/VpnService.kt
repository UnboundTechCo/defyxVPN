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

class DefyxVpnService : VpnService() {
    companion object {
        private const val TAG = "DefyxVpnService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "defyx_vpn_channel"
        @Volatile private lateinit var instance: DefyxVpnService
        fun getInstance(): DefyxVpnService = instance
        private var vpnInterface: ParcelFileDescriptor? = null
        private var listener: ((String) -> Unit)? = null
        private val cleanupMutex = Mutex()
        private var tunnelFd = -1
        private var tunnelFdPassedToCore = false
        private var isServiceRunning = false
        private var isVpnConnected = false
        private var connectionMethod: String? = ""

        fun setVpnStatusListener(l: (String) -> Unit) {
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
    }

    override fun onDestroy() {
        log("VPN Service Destroyed")
        disconnectVpn()
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
        CoroutineScope(Dispatchers.IO).launch {
            Log.d(TAG, "startVpn called")
            try {
                notifyVpnStatus("connecting")
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

                isVpnConnected = vpnInterface != null
                withContext(Dispatchers.Main) { saveVpnState(isVpnConnected) }

                if (vpnInterface != null) {
                    try {
                        val fd = vpnInterface?.detachFd() ?: -1
                        Log.d(TAG, "Tunnel fd: $fd")

                        if (fd > 0) {
                            tunnelFd = fd
                            vpnInterface = null
                            try {
                                Android.startT2S(tunnelFd.toLong(), "127.0.0.1:5000")
                                tunnelFdPassedToCore = true
                                updateNotification("DefyxVPN", "Connected by " + connectionMethod)
                                notifyVpnStatus("connected")
                                onConnected()
                            } catch (e: Exception) {
                                Log.e(TAG, "T2S failed: ${e.message}", e)
                                failVpnStartup(e, onFailure)
                            }
                        } else {
                                failVpnStartup(
                                    IllegalStateException("VPN tunnel descriptor is invalid"),
                                    onFailure
                                )
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "detachFd failed: ${e.message}", e)
                        failVpnStartup(e, onFailure)
                    }
                } else {
                    Log.e(TAG, "vpnInterface is null")
                        failVpnStartup(
                            IllegalStateException("VPN interface could not be established"),
                            onFailure
                        )
                }
            } catch (e: Exception) {
                Log.e(TAG, "startVpn failed: ${e.message}", e)
                failVpnStartup(e, onFailure)
            }
        }
    }

    private suspend fun failVpnStartup(error: Throwable, onFailure: (Throwable) -> Unit = {}) {
        Log.e(TAG, "VPN startup failed", error)
        cleanupVpn("disconnected")
        onFailure(error)
    }

    private fun disconnectVpn() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                withContext(Dispatchers.Main) {
                    notifyVpnStatus("disconnecting")
                    updateNotification("DefyxVPN", "Disconnecting...")
                }

                cleanupVpn("disconnected")
            } catch (e: Exception) {
                log("Error stopping VPN: ${e.message}")
            }
        }
    }

    private suspend fun cleanupVpn(status: String) {
        cleanupMutex.withLock {
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
            }

            saveVpnState(false)
            withContext(Dispatchers.Main) {
                notifyVpnStatus(status)
                stopForeground(STOP_FOREGROUND_REMOVE)
                val notificationManager =
                        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(NOTIFICATION_ID)
            }
        }
    }

    fun stopVpn() {
        disconnectVpn()
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
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed")
        disconnectVpn()
    }

    override fun onRevoke() {
        Log.d("VPN_SERVICE", "Revoked")
        disconnectVpn()
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
}
