package com.example.google_map_location_picker

import android.app.Activity
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import androidx.annotation.NonNull
import androidx.annotation.UiThread
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.math.BigInteger
import java.security.MessageDigest

class GoogleMapLocationPickerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "google_map_location_picker")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    @UiThread
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getSigningCertSha1" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    val currentActivity = activity
                    if (currentActivity == null) {
                        result.error("NO_ACTIVITY", "Activity not available", null)
                        return
                    }
                    
                    try {
                        val info: PackageInfo = currentActivity.packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                        val signatures = info.signatures
                        if (signatures != null && signatures.isNotEmpty()) {
                            for (signature in signatures) {
                                val md: MessageDigest = MessageDigest.getInstance("SHA1")
                                md.update(signature.toByteArray())

                                val bytes: ByteArray = md.digest()
                                val bigInteger = BigInteger(1, bytes)
                                val hex: String = String.format("%0${bytes.size shl 1}x", bigInteger)

                                result.success(hex)
                                return
                            }
                        } else {
                            result.error("NO_SIGNATURES", "No signatures found for package", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.toString(), null)
                        return
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Package name must not be null", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}
