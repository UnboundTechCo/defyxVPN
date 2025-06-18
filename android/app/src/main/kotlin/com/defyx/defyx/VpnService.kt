package de.unboundtech.defyxvpn

import android.app.*
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.edit
import kotlinx.coroutines.*
import android.content.pm.ServiceInfo

class DefyxVpnService : VpnService() {
    companion object {
        private const val TAG = "DefyxVpnService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "defyx_vpn_channel"
        @Volatile private var instance: DefyxVpnService? = null
        private var vpnInterface: ParcelFileDescriptor? = null
        private var listener: ((String) -> Unit)? = null
        private var isServiceRunning = false

        fun getInstance(): DefyxVpnService {
            if (instance == null) synchronized(this) { if (instance == null) instance = DefyxVpnService() }
            return instance!!
        }

        fun setVpnStatusListener(l: (String) -> Unit) { listener = l }
        fun notifyVpnStatus(status: String) { listener?.invoke(status) }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "DefyxVPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keep DefyxVPN running in background"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
    }

    private fun startAsForeground() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DefyxVPN")
            .setContentText("VPN connection is active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            isServiceRunning = true
        } catch (e: Exception) {
            startForeground(NOTIFICATION_ID, notification)
            isServiceRunning = true
        }
    }

    fun startVpn(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            Log.d(TAG, "Starting dummy VPN service")
            try {
                notifyVpnStatus("connecting")
                val intent = Intent(context, DefyxVpnService::class.java).apply { action = "START_VPN" }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    context.startForegroundService(intent)
                else context.startService(intent)
                
                delay(500) // Simulate connection delay
                isServiceRunning = true
                withContext(Dispatchers.Main) { saveVpnState(context, true) }
                notifyVpnStatus("connected")
                
                if (isServiceRunning) startAsForeground()
            } catch (e: Exception) {
                Log.e(TAG, "Exception in dummy startVpn: ${e.message}", e)
                notifyVpnStatus("disconnected")
                withContext(Dispatchers.Main) { saveVpnState(context, false) }
            }
        }
    }

    fun startWarp(config: Map<String, Any>): Boolean = try {
        Log.d(TAG, "Starting dummy Warp+ service")
        // Just return success without doing anything
        true
    } catch (e: Exception) {
        Log.e(TAG, "Error in dummy startWarp: ${e.message}", e)
        false
    }

    fun stopTun2Socks() {
        Log.d(TAG, "Dummy stopTun2Socks called")
        // No-op dummy implementation
    }

    fun stopVpn() {
        try {
            Log.d(TAG, "Stopping dummy VPN service")
            notifyVpnStatus("disconnecting")
            
            try {
                vpnInterface?.close()
            } catch (_: Exception) {}
            vpnInterface = null

            stopForeground(true)
            stopSelf()
            isServiceRunning = false
            saveVpnState(this, false)
            notifyVpnStatus("disconnected")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping dummy VPN: ${e.message}", e)
        }
    }

    suspend fun stopWarp(): Boolean {
        Log.d(TAG, "Stopping dummy Warp+ service")
        return try {
            delay(100) // Simulate some work
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error in dummy stopWarp: ${e.message}", e)
            false
        }
    }

    fun getLogs(): String = "Dummy VPN service - no logs available"

    fun getVpnStatus(): String = if (isServiceRunning) "connected" else "disconnected"

    override fun onDestroy() {
        super.onDestroy()
        Log.d("VPN_SERVICE","Destroyed")
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (isServiceRunning) startAsForeground()
    }
    
    override fun onRevoke() {
        super.onRevoke()
        Log.d("VPN_SERVICE","Revoked")
    }

    private fun saveVpnState(context: Context, isRunning: Boolean) {
        context.getSharedPreferences("defyx_vpn_prefs", Context.MODE_PRIVATE)
            .edit { putBoolean("vpn_running", isRunning) }
    }
}
