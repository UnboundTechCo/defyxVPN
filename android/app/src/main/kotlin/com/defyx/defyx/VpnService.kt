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
import kotlinx.coroutines.*

class DefyxVpnService : VpnService() {
    companion object {
        private const val TAG = "DefyxVpnService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "defyx_vpn_channel"
        @Volatile private lateinit var instance: DefyxVpnService
        fun getInstance(): DefyxVpnService = instance
        private var vpnInterface: ParcelFileDescriptor? = null
        private var listener: ((String) -> Unit)? = null
        private var tunnelFd = -1
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
        startAsForeground("DefyxVPN", "Ready to connect")
    }

    override fun onDestroy() {
        super.onDestroy()
        log("VPN Service Destroyed")
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
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground: ${e.message}", e)
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (e2: Exception) {
                Log.e(TAG, "Fallback failed: ${e2.message}", e2)
            }
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

    fun startVpn(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            Log.d(TAG, "startVpn called")
            try {
                notifyVpnStatus("connecting")
                updateNotification("DefyxVPN", "Connecting...")

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
                                updateNotification("DefyxVPN", "Connected by " + connectionMethod)
                                notifyVpnStatus("connected")
                            } catch (e: Exception) {
                                Log.e(TAG, "T2S failed: ${e.message}", e)
                                updateNotification("DefyxVPN", "Connection failed")
                                notifyVpnStatus("disconnected")
                            }
                        } else {
                            tunnelFd = -1
                            updateNotification("DefyxVPN", "Connection failed")
                            notifyVpnStatus("disconnected")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "detachFd failed: ${e.message}", e)
                        updateNotification("DefyxVPN", "Connection failed")
                        notifyVpnStatus("disconnected")
                    }
                } else {
                    Log.e(TAG, "vpnInterface is null")
                    updateNotification("DefyxVPN", "Connection failed")
                    notifyVpnStatus("disconnected")
                }
            } catch (e: Exception) {
                Log.e(TAG, "startVpn failed: ${e.message}", e)
                updateNotification("DefyxVPN", "Connection failed")
                notifyVpnStatus("disconnected")
                withContext(Dispatchers.Main) { saveVpnState(false) }
            }
        }
    }

    private fun disconnectVpn() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                withContext(Dispatchers.Main) {
                    notifyVpnStatus("disconnecting")
                    updateNotification("DefyxVPN", "Disconnecting...")
                }

                Android.stop()

                try {
                    vpnInterface?.close()
                } catch (_: Exception) {}
                vpnInterface = null

                stopTun2Socks()
                tunnelFd = -1
                isVpnConnected = false

                saveVpnState(false)

                withContext(Dispatchers.Main) {
                    notifyVpnStatus("disconnected")
                    updateNotification("DefyxVPN", "Disconnected")
                }

            } catch (e: Exception) {
                log("Error stopping VPN: ${e.message}")
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

    fun connectVPN(cacheDir: String, flowLine: String, pattern: String) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Android.startVPN(cacheDir, flowLine, pattern)
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

    fun getFlowLine(isTest: Boolean): String {
        return try {
            Android.getFlowLine(isTest)
        } catch (e: Exception) {
            log("Get Flow Line failed: ${e.message}")
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
    }

    override fun onRevoke() {
        super.onRevoke()
        Log.d("VPN_SERVICE", "Revoked")
    }

    private fun saveVpnState(isRunning: Boolean) {
        applicationContext.getSharedPreferences("defyx_vpn_prefs", Context.MODE_PRIVATE).edit {
            putBoolean("vpn_running", isRunning)
        }
    }
    fun setConnectionMethod(method: String) {
        connectionMethod = method
    }
}
