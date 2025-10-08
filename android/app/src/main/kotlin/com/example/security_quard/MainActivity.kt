package com.example.security_quard

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface

class MainActivity : FlutterFragmentActivity() {
    private val biometricChannelName = "com.example.security_quard/biometric_capabilities"
    private val securityChannelName = "com.example.security_quard/environment_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, biometricChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "detect") {
                    val pm = packageManager
                    val capabilities = mutableListOf<String>()

                    if (pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)) {
                        capabilities.add("fingerprint")
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        pm.hasSystemFeature(PackageManager.FEATURE_FACE)) {
                        capabilities.add("face")
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                        pm.hasSystemFeature(PackageManager.FEATURE_IRIS)) {
                        capabilities.add("iris")
                    }

                    result.success(capabilities)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "evaluate") {
                    val status = mapOf(
                        "vpnActive" to isVpnActive(),
                        "mockLocationApps" to hasMockLocationApps(),
                        "mockLocationSetting" to isMockLocationEnabledLegacy()
                    )
                    result.success(status)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun isVpnActive(): Boolean {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return fallbackVpnCheck()

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivityManager.allNetworks.any { network ->
                connectivityManager.getNetworkCapabilities(network)?.hasTransport(
                    NetworkCapabilities.TRANSPORT_VPN
                ) == true
            } || fallbackVpnCheck()
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.getNetworkInfo(ConnectivityManager.TYPE_VPN)
            networkInfo?.isConnected == true || fallbackVpnCheck()
        }
    }

    private fun fallbackVpnCheck(): Boolean {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return false
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (!networkInterface.isUp || networkInterface.isLoopback) {
                    continue
                }
                val name = networkInterface.displayName?.lowercase() ?: continue
                if (name.contains("tun") || name.contains("ppp") || name.contains("vpn")) {
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun hasMockLocationApps(): Boolean {
        return try {
            val pm = packageManager
            val packages: List<PackageInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
            }

            packages.any { info ->
                if (info.packageName == packageName) {
                    return@any false
                }
                val permissions = info.requestedPermissions ?: return@any false
                val hasMockPermission = permissions.any { permission ->
                    permission == "android.permission.ACCESS_MOCK_LOCATION"
                }
                if (!hasMockPermission) {
                    return@any false
                }
                val appInfo: ApplicationInfo? = info.applicationInfo
                val isSystemApp = appInfo != null && (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                !isSystemApp
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isMockLocationEnabledLegacy(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return false
        }
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ALLOW_MOCK_LOCATION) != "0"
        } catch (_: Exception) {
            false
        }
    }
}
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
