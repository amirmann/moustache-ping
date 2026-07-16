package com.amirmann.moustache_ping

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.Inet6Address

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.amirmann.moustache_ping/network_info",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNetworkInterfaces" -> {
                    try {
                        result.success(readNetworkInterfaces())
                    } catch (e: Exception) {
                        result.error("network_info_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readNetworkInterfaces(): Map<String, Any?> {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        var wifi: Map<String, Any?>? = null
        var cellular: Map<String, Any?>? = null

        fun assign(caps: NetworkCapabilities, info: Map<String, Any?>) {
            when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> {
                    if (wifi == null) wifi = info
                }
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> cellular = info
            }
        }

        cm.activeNetwork?.let { network ->
            val caps = cm.getNetworkCapabilities(network) ?: return@let
            val link = cm.getLinkProperties(network) ?: return@let
            assign(caps, buildInterfaceInfo(link))
        }

        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            val link = cm.getLinkProperties(network) ?: continue
            val info = buildInterfaceInfo(link)

            when {
                (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) &&
                    wifi == null -> wifi = info
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) &&
                    cellular == null -> cellular = info
            }
        }

        return mapOf(
            "wifi" to wifi,
            "cellular" to cellular,
        )
    }

    private fun buildInterfaceInfo(link: LinkProperties): Map<String, Any?> {
        var ipv4: String? = null
        var ipv6: String? = null
        var subnetMask: String? = null

        for (addr in link.linkAddresses) {
            val ip = addr.address
            when {
                ip is Inet4Address && !ip.isLoopbackAddress -> {
                    ipv4 = ip.hostAddress
                    subnetMask = prefixToMask(addr.prefixLength)
                }
                ip is Inet6Address &&
                    !ip.isLoopbackAddress &&
                    !ip.isLinkLocalAddress -> {
                    ipv6 = ip.hostAddress
                }
            }
        }

        var gateway: String? = null
        for (route in link.routes) {
            val gw = route.gateway
            if (gw is Inet4Address && !gw.isAnyLocalAddress) {
                if (route.isDefaultRoute) {
                    gateway = gw.hostAddress
                    break
                }
                if (gateway == null) gateway = gw.hostAddress
            }
        }

        val dnsList = mutableListOf<String>()
        for (server in link.dnsServers) {
            val raw = server.hostAddress?.trim().orEmpty()
            if (raw.isEmpty()) continue
            // Strip IPv6 zone id (e.g. %wlan0) — not useful in the UI and wraps badly.
            val cleaned = raw.substringBefore('%')
            if (cleaned.isNotEmpty()) dnsList.add(cleaned)
        }
        val privateDns = link.privateDnsServerName?.trim()
        if (!privateDns.isNullOrEmpty() && dnsList.none { it == privateDns }) {
            dnsList.add(privateDns)
        }
        // Prefer IPv4 first so the useful router DNS isn't buried under link-local IPv6.
        dnsList.sortWith(compareBy({ it.contains(':') }, { it }))
        val dnsServers = dnsList.distinct()

        return mapOf(
            "interfaceName" to link.interfaceName,
            "ipv4" to ipv4,
            "ipv6" to ipv6,
            "subnetMask" to subnetMask,
            "gateway" to gateway,
            "dnsServers" to dnsServers.ifEmpty { null },
            "connected" to (ipv4 != null || ipv6 != null),
        )
    }

    private fun prefixToMask(prefix: Int): String {
        val mask = IntArray(4)
        var remaining = prefix
        for (i in 0..3) {
            val bits = if (remaining >= 8) 8 else remaining.coerceAtLeast(0)
            mask[i] = if (bits == 0) 0 else (0xff shl (8 - bits)) and 0xff
            remaining -= bits
        }
        return mask.joinToString(".")
    }
}
