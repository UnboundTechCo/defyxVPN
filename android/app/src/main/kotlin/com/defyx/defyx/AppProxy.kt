package de.unboundtech.defyxvpn

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ProxySelector
import java.net.SocketAddress
import java.net.URI

/**
 * Sends the app's own Java and web view traffic through the VPN while the
 * tunnel is up.
 *
 * The app's package is left out of the tunnel, because the core runs in it
 * and its transports dial their servers without protect(). Everything else the
 * app opens (Firebase, AdMob, the consent form, the in-app web pages) would
 * then leave over the direct connection and show the user's real address.
 * While the tunnel is up those requests go to the core's local proxy instead.
 * Dart's HTTP is handled the same way by AppTraffic on the Flutter side.
 *
 * Java HTTP goes through the default [ProxySelector], which HttpURLConnection
 * and OkHttp ask on every request. Android's built-in HttpURLConnection still
 * tries a direct connection when the proxy refuses it, which only happens
 * while the core is down and the tunnel kept up. Web views use a process-wide
 * proxy override and fail instead.
 */
object AppProxy {
    private const val TAG = "AppProxy"

    // The core's mixed HTTP and SOCKS inbound, the same one AppTraffic uses.
    private const val HOST = "127.0.0.1"
    private const val PORT = 5000

    @Volatile private var enabled = false
    private var installed = false
    private val main = Handler(Looper.getMainLooper())

    /** Puts the selector in place once per process. Safe to call again. */
    @Synchronized
    fun install() {
        if (installed) return
        ProxySelector.setDefault(Selector(ProxySelector.getDefault()))
        installed = true
    }

    /** Turns the proxy on when the tunnel is up and off when it is gone. */
    fun setEnabled(on: Boolean) {
        if (enabled == on) return
        enabled = on
        main.post { applyToWebViews(on) }
    }

    private fun isLocal(host: String?): Boolean =
            host == null ||
                    host == HOST ||
                    host == "localhost" ||
                    host == "::1" ||
                    host == "[::1]"

    private fun applyToWebViews(on: Boolean) {
        try {
            if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
                Log.w(TAG, "Web view cannot take a proxy override on this device")
                return
            }
            val controller = ProxyController.getInstance()
            if (on) {
                val config = ProxyConfig.Builder().addProxyRule("$HOST:$PORT").build()
                controller.setProxyOverride(config, { it.run() }) {
                    Log.d(TAG, "Web views use the VPN proxy")
                }
            } else {
                controller.clearProxyOverride({ it.run() }) {
                    Log.d(TAG, "Web views connect directly")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to change the web view proxy: ${e.message}", e)
        }
    }

    private class Selector(private val fallback: ProxySelector?) : ProxySelector() {
        private val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress(HOST, PORT))

        override fun select(uri: URI?): List<Proxy> {
            if (enabled && !isLocal(uri?.host)) return listOf(proxy)
            return fallback?.select(uri) ?: listOf(Proxy.NO_PROXY)
        }

        override fun connectFailed(uri: URI?, address: SocketAddress?, error: IOException?) {
            if (uri == null || address == null || error == null) return
            try {
                fallback?.connectFailed(uri, address, error)
            } catch (_: Exception) {}
        }
    }
}
