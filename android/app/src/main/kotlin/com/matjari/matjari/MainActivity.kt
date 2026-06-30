package com.matjari.matjari

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "matjari/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> result.success(openUrl(call.argument("url")))
                    "openPackage" -> result.success(openPackage(call.argument("packageName")))
                    "installedVersionCode" -> result.success(installedVersionCode(call.argument("packageName")))
                    else -> result.notImplemented()
                }
            }
    }

    private fun openUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) return false

        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun openPackage(packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false

        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun installedVersionCode(packageName: String?): Long? {
        if (packageName.isNullOrBlank()) return null

        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (_: Exception) {
            null
        }
    }
}
