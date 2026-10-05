package com.teamorigin.mool

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "app.mool/native"
    private var methodChannel: MethodChannel? = null
    private var initialRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val isGetHelp = intent.action == GetHelpWidgetProvider.ACTION_GET_HELP ||
                intent.getStringExtra("route") == "get_help"
        if (isGetHelp) {
            initialRoute = "get_help"
            methodChannel?.invokeMethod("onNavigateRoute", "get_help")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> sendSms(call.argument("phone"), call.argument("message"), result)
                "placeCall" -> placeCall(call.argument("number"), result)
                "getInitialRoute" -> {
                    val route = initialRoute
                    initialRoute = null
                    result.success(route)
                }
                else -> result.notImplemented()
            }
        }
        handleIntent(intent)
    }

    private fun hasPermission(permission: String): Boolean =
        Build.VERSION.SDK_INT < 23 ||
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun sendSms(phone: String?, message: String?, result: MethodChannel.Result) {
        if (phone.isNullOrBlank() || message.isNullOrBlank()) {
            result.error("ARGS", "phone and message are required", null)
            return
        }
        if (!hasPermission(Manifest.permission.SEND_SMS)) {
            result.error("PERMISSION", "SMS permission is off", null)
            return
        }
        try {
            val sms: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            // Messages over 160 characters must be split. Abhaya used a single
            // sendTextMessage call, which silently drops long messages.
            val parts = sms.divideMessage(message)
            if (parts.size > 1) {
                sms.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                sms.sendTextMessage(phone, null, message, null, null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SMS_FAILED", e.message, null)
        }
    }

    private fun placeCall(number: String?, result: MethodChannel.Result) {
        if (number.isNullOrBlank()) {
            result.error("ARGS", "number is required", null)
            return
        }
        try {
            // With CALL_PHONE the call starts directly; otherwise open the dialer.
            val action = if (hasPermission(Manifest.permission.CALL_PHONE)) Intent.ACTION_CALL else Intent.ACTION_DIAL
            val intent = Intent(action, Uri.parse("tel:$number")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(action == Intent.ACTION_CALL)
        } catch (e: Exception) {
            result.error("CALL_FAILED", e.message, null)
        }
    }
}
