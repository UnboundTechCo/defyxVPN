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
        super.onDestroy()
        log("VPN Service Destroyed")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
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

    private fun startAsForeground() {
        val intent =
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
        val pendingIntent =
                PendingIntent.getActivity(
                        this,
                        0,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
        val notification =
                NotificationCompat.Builder(this, CHANNEL_ID)
                        .setContentTitle("DefyxVPN")
                        .setContentText("VPN connection is active")
                        .setSmallIcon(android.R.drawable.ic_lock_lock)
                        .setContentIntent(pendingIntent)
                        .setOngoing(true)
                        .setAutoCancel(false)
                        .setCategory(NotificationCompat.CATEGORY_SERVICE)
                        .setPriority(NotificationCompat.PRIORITY_LOW)
                        .setForegroundServiceBehavior(
                                NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE
                        )
                        .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.d(TAG, "Service started as foreground")
            isServiceRunning = true
        } catch (e: Exception) {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Service started as foreground")
            isServiceRunning = true
        }
    }

    fun startVpn(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            Log.d(TAG, "Coroutine started for startVpn")
            try {
                notifyVpnStatus("connecting")
                val intent =
                        Intent(context, DefyxVpnService::class.java).apply { action = "START_VPN" }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        context.startForegroundService(intent)
                else context.startService(intent)
                delay(500)
                val builder =
                        Builder()
                                .setSession("DefyxVPN")
                                .addAddress("10.0.0.2", 32)
                                .addRoute("0.0.0.0", 0)
                                .addDnsServer("1.1.1.1")
                                .allowFamily(android.system.OsConstants.AF_INET)
                                //
                                // .allowFamily(android.system.OsConstants.AF_INET6)
                                .setMtu(1500)
                                .setBlocking(true)
                                .allowBypass()
                try {
                    builder.addDisallowedApplication(context.packageName)
                } catch (_: Exception) {}
                vpnInterface?.close()
                vpnInterface = builder.establish()
                Log.d(TAG, "vpnInterface after establish: $vpnInterface")
                isServiceRunning = vpnInterface != null
                withContext(Dispatchers.Main) { saveVpnState(isServiceRunning) }
                notifyVpnStatus(if (isServiceRunning) "connected" else "disconnected")

                if (vpnInterface != null) {
                    Log.d(TAG, "vpnInterface not null, ready for detachFd")
                    try {
                        val fd =
                                vpnInterface?.detachFd()?.also {
                                    Log.d(TAG, "detachFd() returned: $it")
                                }
                                        ?: -1
                        Log.d(TAG, "Tunnel fd is : $fd")
                        if (fd > 0) {
                            tunnelFd = fd
                            vpnInterface = null
                            try {
                                Log.d(TAG, "About to call Android.startT2S")
                                Android.startT2S(tunnelFd.toLong(), "127.0.0.1:5000")
                                Log.d(TAG, "Android.startT2S called successfully")
                            } catch (e: Exception) {
                                Log.e(TAG, "Exception in startT2S: ${e.message}", e)
                            }
                        } else {
                            tunnelFd = -1
                            Log.e(TAG, "Failed to get tunnel fd, got $fd")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Exception during detachFd or startT2S: ${e.message}", e)
                    }
                } else {
                    Log.e(TAG, "vpnInterface is null after establish, VPN was NOT started!")
                }

                if (isServiceRunning) startAsForeground()
            } catch (e: Exception) {
                Log.e(TAG, "Exception in startVpn: ${e.message}", e)
                notifyVpnStatus("disconnected")
                withContext(Dispatchers.Main) { saveVpnState(false) }
            }
        }
    }

    fun stopTun2Socks() {
        try {
            Android.stopT2S()
        } catch (e: Exception) {
            log("Stop T2S failed: ${e.message}")
        }
    }

    fun measurePing(): Long {
        try {
            val ping = Android.measurePing()
            return ping
        } catch (e: Exception) {
            log("Measure Ping failed: ${e.message}")
            return 0
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
        try {
            val flag = Android.getFlag()
            return flag
        } catch (e: Exception) {
            log("Get Flag failed: ${e.message}")
            return ""
        }
    }

    fun stopVpn() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // notify on main thread
                withContext(Dispatchers.Main) { notifyVpnStatus("disconnecting") }

                Android.stop()

                try {
                    vpnInterface?.close()
                } catch (_: Exception) {}
                vpnInterface = null
                stopTun2Socks()

                tunnelFd = -1

                if (isServiceRunning) {
                    stopForeground(true)
                    isServiceRunning = false
                }

                saveVpnState(false)
                withContext(Dispatchers.Main) { notifyVpnStatus("disconnected") }
                stopSelf()
            } catch (e: Exception) {
                // Log.e(TAG, "Error stopping VPN: ${e.message}", e)
                log("Error stopping VPN: ${e.message}")
            }
        }
    }

    fun setAsnName() {
        try {
            Android.setAsnName()
        } catch (e: Exception) {
            // Log.e("Set ASN Name", "Set ASN Name failed: ${e.message}", e)
            log("Set ASN Name failed: ${e.message}")
        }
    }

    fun setTimezone(timezone: Float) {
        try {
            Android.setTimeZone(timezone)
        } catch (e: Exception) {
            // Log.e("Set Local Timezone", "Set Local Timezone failed: ${e.message}", e)
            log("Set Local Timezone failed: ${e.message}")
        }
    }

    fun getFlowLine(isTest: Boolean): String {
        try {
            return Android.getFlowLine(isTest)
        } catch (e: Exception) {
            log("Get Flow Line failed: ${e.message}")
            return ""
        }
    }

    fun log(message: String) {
        try {
            Android.log(message)
        } catch (e: Exception) {
            Log.e("Get Flow Line", "Get Flow Line failed: ${e.message}", e)
        }
    }

    fun getVpnStatus(): String =
            if (isServiceRunning && vpnInterface != null) "connected" else "disconnected"
    fun isTunnelRunning(): Boolean {
        return tunnelFd > 0
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (isServiceRunning) startAsForeground()
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
}
