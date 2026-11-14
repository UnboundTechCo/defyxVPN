package de.unboundtech.defyxvpn

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.os.Build
import android.provider.Settings

object PrivateDns {
    /**
     * The hostname set for Private DNS, or null when it is off or automatic.
     *
     * With a hostname, Android sends all DNS of other apps to that server over
     * TLS, through the VPN, and does not fall back to anything else. Servers
     * that only answer addresses of their own country or customers then fail
     * while connected, and every app looks offline.
     */
    fun host(context: Context): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        return try {
            val connectivity =
                    context.getSystemService(ConnectivityManager::class.java) ?: return null
            // Once connected the VPN is the active network, so the networks
            // under it are checked too.
            @Suppress("DEPRECATION")
            val networks = listOfNotNull(connectivity.activeNetwork) + connectivity.allNetworks
            networks.firstNotNullOfOrNull { network ->
                connectivity.getLinkProperties(network)?.privateDnsServerName?.takeIf {
                    it.isNotBlank()
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Opens the network settings, where Private DNS is. Android has no public
     * screen for Private DNS itself, and Android TV may have neither.
     */
    fun openSettings(context: Context): Boolean {
        for (action in listOf(Settings.ACTION_WIRELESS_SETTINGS, Settings.ACTION_SETTINGS)) {
            try {
                context.startActivity(
                        Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return true
            } catch (_: Exception) {}
        }
        return false
    }
}
