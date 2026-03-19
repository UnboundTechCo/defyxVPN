package de.unboundtech.defyxvpn

import android.Android
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONObject

/**
 * VPN event structure for structured communication from Go cores
 */
data class VPNEvent(
    val event: String,
    val core: String,
    val data: Map<String, Any>
)

/**
 * Progress listener that receives messages from Go VPN cores
 * Handles both structured JSON events and plain log messages
 */
class ProgressStreamHandler(private val vpnService: DefyxVpnService) : Android.ProgressListener {
    
    companion object {
        private const val TAG = "ProgressStreamHandler"
    }
    
    override fun onProgress(msg: String?) {
        Log.d(TAG, "🔔 [PROGRESS-ENTRY] onProgress() CALLED!")
        
        if (msg == null) {
            Log.w(TAG, "⚠️ [PROGRESS] Received null message")
            return
        }
        
        Log.d(TAG, "🔵 [PROGRESS] Received message (length: ${msg.length}): $msg")
        
        // Try to parse as VPN event (JSON)
        parseVPNEvent(msg)?.let { event ->
            Log.d(TAG, "✅ [PROGRESS] Successfully parsed as VPN event")
            handleVPNEvent(event)
            return
        }
        
        Log.d(TAG, "🔵 [PROGRESS] Not a VPN event, treating as log message")
        // Otherwise treat as regular log message
        logMessage(msg)
    }
    
    private fun parseVPNEvent(message: String): VPNEvent? {
        Log.d(TAG, "🔵 [PARSE] Attempting to parse as JSON...")
        return try {
            val json = JSONObject(message)
            Log.d(TAG, "✅ [PARSE] Deserialized JSON: $json")
            
            val event = json.optString("event", null)
            val core = json.optString("core", null)
            
            if (event == null || core == null) {
                Log.w(TAG, "❌ [PARSE] Missing 'event' or 'core' field")
                return null
            }
            
            val dataJson = json.optJSONObject("data")
            val data = mutableMapOf<String, Any>()
            dataJson?.let {
                it.keys().forEach { key ->
                    data[key] = it.get(key)
                }
            }
            
            Log.d(TAG, "✅ [PARSE] Parsed VPNEvent - event: $event, core: $core")
            VPNEvent(event, core, data)
        } catch (e: Exception) {
            Log.w(TAG, "❌ [PARSE] Failed to deserialize JSON: ${e.message}")
            null
        }
    }
    
    private fun handleVPNEvent(event: VPNEvent) {
        Log.d(TAG, "📡 [EVENT] VPN Event: ${event.event} from ${event.core}, data: ${event.data}")
        
        when (event.event) {
            "PROXY_READY" -> handleProxyReady(event)
            "TUNNEL_CONNECTED" -> Log.d(TAG, "✅ [EVENT] Tunnel connected: ${event.core}")
            "TUNNEL_FAILED" -> Log.e(TAG, "❌ [EVENT] Tunnel failed: ${event.core}")
            else -> Log.w(TAG, "⚠️ [EVENT] Unknown event type: ${event.event}")
        }
    }
    
    private fun handleProxyReady(event: VPNEvent) {
        Log.d(TAG, "🎯🎯🎯 [PROXY_READY] handleProxyReady() CALLED!")
        val port = (event.data["port"] as? Number)?.toInt() ?: 5000
        Log.d(TAG, "✅ [PROXY_READY] Proxy ready on port $port from core: ${event.core}")
        Log.d(TAG, "🔵 [PROXY_READY] Waiting 200ms for stabilization...")
        
        // Small delay to ensure proxy is fully accepting connections
        // tun2socks doesn't retry connection attempts, so we need to ensure port is truly ready
        CoroutineScope(Dispatchers.IO).launch {
            delay(200L) // 200ms stabilization delay
            Log.d(TAG, "🔵 [PROXY_READY] Stabilization complete, starting tun2socks...")
            vpnService.startTun2socksFromEvent(event.core)
        }
    }
    
    private fun logMessage(message: String) {
        // Forward to existing log mechanism (Android.log or other)
        try {
            Android.log(message)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log message: ${e.message}")
        }
    }
}
