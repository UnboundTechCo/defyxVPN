package de.unboundtech.defyxvpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.util.Log
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import android.os.Handler
import android.os.Looper
import java.net.*
import okhttp3.OkHttpClient
import okhttp3.Request

private const val VPN_REQUEST_CODE = 1000
private const val TAG = "MainActivity"

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.defyx.warp_plus"
    private val STATUS_CHANNEL = "com.defyx.warp_plus_events"
    private var eventSink: EventChannel.EventSink? = null
    private var pendingVpnResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            lifecycleScope.launch { handleMethodCall(call, result) }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STATUS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    sendVpnStatusToFlutter("disconnected")
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private suspend fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> connectVpn(result)
            "disconnect" -> disconnectVpn(result)
            "prepare" -> prepareVpn(result)
            "getLogs" -> getLogs(result)
            "startWarpPlus" -> startWarpPlus(call.arguments as? Map<String, Any>, result)
            "stopWarp" -> stopWarp(result)
            "startTun2socks" -> result.success(null)  //startTun2Socks(result)
            "getVpnStatus" -> getVpnStatus(result)
            "stopTun2Socks" -> stopTun2Socks(result)
            "calculatePing" -> calculatePing(result)
            "getFlag" -> getFlag(result)
            else -> result.notImplemented()
        }
    }

    

    private suspend fun prepareVpn(result: MethodChannel.Result) {
        val vpnIntent = VpnService.prepare(this)
        if (vpnIntent != null) {
            startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
        } else {
            result.success(true)
        }
    }

    private fun connectVpn(result: MethodChannel.Result) {
        pendingVpnResult = result

        //DefyxVpnService.setVpnStatusListener { status -> sendVpnStatusToFlutter(status) }

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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                DefyxVpnService.getInstance().startVpn(this)
                pendingVpnResult?.success(true)
            } else {
                sendVpnStatusToFlutter("disconnected")
                pendingVpnResult?.success(false)
            }
            pendingVpnResult = null
        }
    }

    private fun disconnectVpn(result: MethodChannel.Result) = try {
        DefyxVpnService.getInstance().stopVpn()
        sendVpnStatusToFlutter("disconnected")
        result.success(true)
    } catch (e: Exception) {
        result.error("VPN_STOP_ERROR", "Failed to stop VPN", e.message)
    }

    private fun getLogs(result: MethodChannel.Result) = try {
        result.success(DefyxVpnService.getInstance().getLogs())
    } catch (e: Exception) {
        result.error("GET_LOGS_ERROR", "Failed to get logs", e.message)
    }

    private fun startWarpPlus(args: Map<String, Any>?, result: MethodChannel.Result) {
        if (args == null) {
            result.error("INVALID_ARGUMENTS", "Arguments cannot be null", null)
            return
        }
        try {
            val required = listOf("bind", "endpoint", "isScannerActive", "ipv4", "ipv6", "dns", "psiphon", "psiphon_country", "gool")
            if (required.any { args[it] == null }) {
                result.error("MISSING_PARAMETERS", "Missing required parameters", null)
                return
            }
            val config = mapOf(
                "command" to "START_WARP",
                "endpoint" to args["endpoint"]!!,
                "bind_address" to args["bind"]!!,
                "cacheDir" to cacheDir.absolutePath,
                "isScannerActive" to args["isScannerActive"]!!,
                "ipv4" to args["ipv4"]!!,
                "ipv6" to args["ipv6"]!!,
                "dns" to args["dns"]!!,
                "psiphon" to args["psiphon"]!!,
                "psiphon_country" to args["psiphon_country"]!!,
                "gool" to args["gool"]!!
            )
            val success = DefyxVpnService.getInstance().startWarp(config)
            if (success) result.success(true)
            else result.error("WARP_START_FAILED", "Failed to start Warp+ tunnel", null)
        } catch (e: Exception) {
            result.error("WARP_START_ERROR", "Failed to start Warp+", e.message)
        }
    }

    private suspend fun stopWarp(result: MethodChannel.Result) {
        Log.d(TAG, "stopWarp called from Flutter/Channel Log 2")

        val stopped = DefyxVpnService.getInstance().stopWarp()
        if (stopped) result.success(true)
        else result.error("WARP_STOP_ERROR", "Failed to stop Warp+", null)
    }

    private fun getVpnStatus(result: MethodChannel.Result) = try {
        result.success(DefyxVpnService.getInstance().getVpnStatus())
    } catch (e: Exception) {
        result.error("GET_STATUS_ERROR", "Failed to get VPN status", e.message)
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

    private fun stopTun2Socks(result: MethodChannel.Result) = try {
      DefyxVpnService.getInstance().stopTun2Socks()
        result.success(true)
    } catch (e: Exception){
        result.error("STOP_TUN2SOCKS","Failed to stop Tun2Socks", e.message);
    }

    // Blocking function to calculate ping using socks5 proxy at 127.0.0.1:5000
    private fun calculatePing(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val proxy = Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", 5000))
                val url = URL("https://www.google.com/generate_204")
                val startTime = System.currentTimeMillis()

                val connection = (url.openConnection(proxy) as HttpURLConnection).apply {
                    connectTimeout = 10_000
                    readTimeout = 10_000
                    connect()
                }

                val ping = System.currentTimeMillis() - startTime
                Log.d("Ping", "Ping via proxy: ${ping}ms")

                withContext(Dispatchers.Main) {
                    result.success(ping)
                }

            } catch (e: Exception) {
                Log.e("Ping", "Ping failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PING_ERROR", "Failed to calculate ping", e.localizedMessage)
                }

            }
        }
    }
    fun getFlag(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val client = OkHttpClient.Builder()
                    .callTimeout(java.time.Duration.ofSeconds(10))
                    .build()

                val request = Request.Builder()
                    .url("https://connectivity.cloudflareclient.com/cdn-cgi/trace")
                    .build()

                val response = client.newCall(request).execute()
                val body = response.body?.string() ?: "xx"

                val regex = Regex("loc=([A-Z]{2})")
                val match = regex.find(body)
                val flag = match?.groupValues?.get(1)?.lowercase() ?: "xx"

                withContext(Dispatchers.Main) {
                    result.success(flag)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    result.success("xx")
                }
            }
        }
    }
}
