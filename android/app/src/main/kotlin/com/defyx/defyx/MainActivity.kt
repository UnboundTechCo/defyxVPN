package de.unboundtech.defyxvpn

import android.Android
import android.Manifest
import android.ProgressListener
import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.*
import kotlinx.coroutines.*

private const val VPN_REQUEST_CODE = 1000
private const val TAG = "MainActivity"

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.defyx.vpn"
    private val STATUS_CHANNEL = "com.defyx.vpn_events"
    private var eventSink: EventChannel.EventSink? = null
    private var pendingVpnResult: MethodChannel.Result? = null
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1010

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            lifecycleScope.launch { handleMethodCall(call, result) }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STATUS_CHANNEL)
                .setStreamHandler(
                        object : EventChannel.StreamHandler {
                            override fun onListen(
                                    arguments: Any?,
                                    events: EventChannel.EventSink?
                            ) {
                                eventSink = events
                                // sendVpnStatusToFlutter("disconnected")
                            }
                            override fun onCancel(arguments: Any?) {
                                eventSink = null
                            }
                        }
                )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.defyx.progress_events")
                .setStreamHandler(ProgressStreamHandler())
    }
    private fun grantNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val intent = Intent(this, DefyxVpnService::class.java)
        grantNotificationPermission()
        startService(intent)
    }

    private suspend fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "connect" -> connectVpn(result)
                "disconnect" -> disconnectVpn(result)
                "prepareVPN" -> prepareVpn(result)
                "isVPNPrepared" -> prepareVpn(result)
                "startTun2socks" -> result.success(null) // startTun2Socks(result)
                "getVpnStatus" -> getVpnStatus(result)
                "isTunnelRunning" -> isTunnelRunning(result)
                "stopTun2Socks" -> stopTun2Socks(result)
                "calculatePing" -> calculatePing(result)
                "getFlag" -> getFlag(result)
                "startVPN" -> startVPN(call.arguments as? Map<String, Any>, result)
                "stopVPN" -> stopVPN(result)
                "grantVpnPermission" -> grantVpnPermission(result)
                "setAsnName" -> setAsnName(result)
                "setTimezone" -> setTimezone(call.arguments as? Map<String, Any>, result)
                "getFlowLine" -> getFlowLine(call.arguments as? Map<String, Any>, result)
                "setConnectionMethod" -> setConnectionMethod(call.arguments as? Map<String, Any>, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method call: ${call.method}", e)
            result.error("METHOD_ERROR", "Error executing ${call.method}", e.message)
        }
    }

    private suspend fun prepareVpn(result: MethodChannel.Result) {
        val vpnIntent = VpnService.prepare(this)
        if (vpnIntent != null) {
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun connectVpn(result: MethodChannel.Result) {
        pendingVpnResult = result

        // DefyxVpnService.setVpnStatusListener { status -> sendVpnStatusToFlutter(status) }

        val vpnIntent = VpnService.prepare(this)
        if (vpnIntent != null) {
            try {
                startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
            } catch (e: Exception) {
                result.error("VPN_PERMISSION_ERROR", "Failed to request VPN permission", e.message)
            }
        } else {
            DefyxVpnService.getInstance().startVpn(this)
            result.success(true)
        }
    }

    private fun grantVpnPermission(result: MethodChannel.Result) {
        try {
            val vpnIntent = VpnService.prepare(this)
            if (vpnIntent != null) {
                // store the result to respond later
                pendingVpnResult = result
                startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
            } else {
                // permission already granted
                result.success(true)
            }
        } catch (e: SecurityException) {
            // Samsung devices sometimes throw SecurityException
            Log.e(TAG, "SecurityException requesting VPN permission", e)
            result.error("VPN_PERMISSION_DENIED", "VPN permission denied", e.message)
        } catch (e: Exception) {
            Log.e(TAG, "Exception requesting VPN permission", e)
            result.error("VPN_PERMISSION_ERROR", "Failed to request VPN permission", e.message)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == VPN_REQUEST_CODE) {
            val res = pendingVpnResult ?: return
            pendingVpnResult = null

            if (resultCode == Activity.RESULT_OK) {
                res.success(true)
            } else {
                res.success(false)
            }
        }
    }

    private fun disconnectVpn(result: MethodChannel.Result) =
            try {
                DefyxVpnService.getInstance().stopVpn()
                sendVpnStatusToFlutter("disconnected")
                result.success(true)
            } catch (e: Exception) {
                result.error("VPN_STOP_ERROR", "Failed to stop VPN", e.message)
            }

    private fun getVpnStatus(result: MethodChannel.Result) =
            try {
                result.success(DefyxVpnService.getInstance().getVpnStatus())
            } catch (e: Exception) {
                result.error("GET_STATUS_ERROR", "Failed to get VPN status", e.message)
            }
    private fun isTunnelRunning(result: MethodChannel.Result) =
            try {
                result.success(DefyxVpnService.getInstance().isTunnelRunning())
            } catch (e: Exception) {
                result.error("GET_STATUS_ERROR", "Failed to get tunnel status", e.message)
            }

    private fun sendVpnStatusToFlutter(status: String) {
        eventSink?.success(mapOf("status" to status))
    }

    //    private fun startTun2Socks(result: MethodChannel.Result) = try {
    //        DefyxVpnService.getInstance().startTun2socks()
    //        result.success(true)
    //    } catch (e: Exception){
    //        result.error("START_TUN2SOCKS","Failed to start Tun2Socks", e.message);
    //    }

    private fun stopTun2Socks(result: MethodChannel.Result) =
            try {
                DefyxVpnService.getInstance().stopTun2Socks()
                result.success(true)
            } catch (e: Exception) {
                result.error("STOP_TUN2SOCKS", "Failed to stop Tun2Socks", e.message)
            }

    // Blocking function to calculate ping using socks5 proxy at 127.0.0.1:5000
    private fun calculatePing(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val ping = DefyxVpnService.getInstance().measurePing()
                result.success(ping)
            } catch (e: Exception) {
                Log.e("Ping", "Ping failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PING_ERROR", "Failed to calculate ping", e.localizedMessage)
                }
            }
        }
    }

    private fun startVPN(args: Map<String, Any>?, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val flowLine = args?.get("flowLine") as? String
                val pattern = args?.get("pattern") as? String
                if (flowLine.isNullOrEmpty() || pattern.isNullOrEmpty()) {
                    withContext(Dispatchers.Main) {
                        result.error(
                                "INVALID_ARGUMENT",
                                "flowLine or pattern is missing or empty",
                                null
                        )
                    }
                    return@launch
                }
                DefyxVpnService.getInstance().connectVPN(cacheDir.absolutePath, flowLine, pattern)
                result.success(true)
            } catch (e: Exception) {
                Log.e("Start VPN", "Start VPN failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PING_ERROR", "Failed to Start VPN", e.localizedMessage)
                }
            }
        }
    }

    private fun stopVPN(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                DefyxVpnService.getInstance().disconnectVPN()
                result.success(true)
            } catch (e: Exception) {
                Log.e("Stop VPN", "Stop VPN failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PING_ERROR", "Failed to Stop VPN", e.localizedMessage)
                }
            }
        }
    }

    private fun getFlag(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val flag = DefyxVpnService.getInstance().getFlag()
                result.success(flag)
            } catch (e: Exception) {
                e.printStackTrace()
                withContext(Dispatchers.Main) { result.success("xx") }
            }
        }
    }
    private fun setAsnName(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                DefyxVpnService.getInstance().setAsnName()
                result.success("success")
            } catch (e: Exception) {
                e.printStackTrace()
                withContext(Dispatchers.Main) { result.success("failed") }
            }
        }
    }
    private fun setTimezone(args: Map<String, Any>?, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val timezone = args?.get("timezone") as? String
                if (timezone.isNullOrEmpty()) {
                    withContext(Dispatchers.Main) {
                        result.error("INVALID_ARGUMENT", "timezone is missing or empty", null)
                    }
                    return@launch
                }
                val timezoneFloat = timezone.toFloat()
                DefyxVpnService.getInstance().setTimezone(timezoneFloat)
                result.success(true)
            } catch (e: Exception) {
                Log.e("Set Local Timezone", "Set Local Timezone failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PING_ERROR", "Failed to Set Local Timezone", e.localizedMessage)
                }
            }
        }
    }
    private fun getFlowLine(args: Map<String, Any>?, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val isTest = args?.get("isTest") as? String
                if (isTest.isNullOrEmpty()) {
                    withContext(Dispatchers.Main) {
                        result.error("INVALID_ARGUMENT", "isTest is missing or empty", null)
                    }
                    return@launch
                }
                val isTestBoolean = isTest.toBoolean()
                val flowLine = DefyxVpnService.getInstance().getFlowLine(isTestBoolean)
                result.success(flowLine)
            } catch (e: Exception) {
                Log.e("Get Flow Line", "Get Flow Line failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error(
                            "GET_FLOW_LINE_ERROR",
                            "Failed to Get Flow Line",
                            e.localizedMessage
                    )
                }
            }
        }
    }
    private fun setConnectionMethod(args: Map<String, Any>?, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val method = args?.get("method") as? String
                if (method.isNullOrEmpty()) {
                    withContext(Dispatchers.Main) {
                        result.error("INVALID_ARGUMENT", "method is missing or empty", null)
                    }
                    return@launch
                }
                DefyxVpnService.getInstance().setConnectionMethod(method)
                result.success(true)
            } catch (e: Exception) {
                Log.e("Set Connection Method", "Set Connection Method failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PING_ERROR", "Failed to Set Connection Method", e.localizedMessage)
                }
            }
        }
    }
}

class ProgressStreamHandler : EventChannel.StreamHandler, ProgressListener {

    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        Android.setProgressListener(this)
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    override fun onProgress(msg: String?) {
        CoroutineScope(Dispatchers.Main).launch { eventSink?.success(msg) }
    }
}