package com.example.safety_app_prototype

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val POWER_BUTTON_CHANNEL = "power_button_service"
        private const val SMS_CHANNEL = "com.safety.app/sms"
        private const val NOTIFICATION_CHANNEL = "com.safety.app/notifications"
    }
    
    private var powerButtonService: PowerButtonService? = null
    private var methodChannel: MethodChannel? = null
    private var smsMethodChannel: MethodChannel? = null
    private var notificationMethodChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Power Button Service Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, POWER_BUTTON_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startPowerButtonService" -> {
                    startPowerButtonService()
                    result.success(true)
                }
                "stopPowerButtonService" -> {
                    stopPowerButtonService()
                    result.success(true)
                }
                "triggerSOS" -> {
                    triggerSOS()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // SMS Service Channel
        smsMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val success = sendSMS(phoneNumber, message)
                    result.success(success)
                }
                "isSMSAvailable" -> {
                    val available = isSMSAvailable()
                    result.success(available)
                }
                "openSMSApp" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val success = openSMSApp(phoneNumber, message)
                    result.success(success)
                }
                "openSMSAppBulk" -> {
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: emptyList()
                    val message = call.argument<String>("message") ?: ""
                    val success = openSMSAppBulk(phoneNumbers, message)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Notification Service Channel
        notificationMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        notificationMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startNotificationService" -> {
                    val userId = call.argument<String>("userId")
                    startNotificationService(userId)
                    result.success(true)
                }
                "stopNotificationService" -> {
                    stopNotificationService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set the method channel reference in the service
        PowerButtonService.methodChannel = methodChannel
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if we were launched with SOS trigger intent
        handleSOSIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSOSIntent(intent)
    }

    // SMS Methods
    private fun sendSMS(phoneNumber: String, message: String): Boolean {
        return try {
            if (phoneNumber.isBlank() || message.isBlank()) {
                Log.e(TAG, "Phone number or message is blank")
                return false
            }

            // Check SMS permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) 
                != PackageManager.PERMISSION_GRANTED) {
                Log.e(TAG, "SMS permission not granted")
                // Request permission for future use
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), 1)
                return false
            }
            
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            
            if (parts.size == 1) {
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                Log.d(TAG, "Single SMS sent successfully to $phoneNumber")
            } else {
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                Log.d(TAG, "Multipart SMS (${parts.size} parts) sent successfully to $phoneNumber")
            }
            
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception sending SMS to $phoneNumber: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send SMS to $phoneNumber: ${e.message}")
            false
        }
    }

    private fun isSMSAvailable(): Boolean {
        return try {
            val hasTelephony = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
            val hasPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "SMS available: telephony=$hasTelephony, permission=$hasPermission")
            hasTelephony && hasPermission
        } catch (e: Exception) {
            Log.e(TAG, "Error checking SMS availability: ${e.message}")
            false
        }
    }

    private fun openSMSApp(phoneNumber: String, message: String): Boolean {
        return try {
            val smsIntent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("smsto:$phoneNumber")
                putExtra("sms_body", message)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            if (smsIntent.resolveActivity(packageManager) != null) {
                startActivity(smsIntent)
                Log.d(TAG, "SMS app opened for $phoneNumber")
                true
            } else {
                Log.e(TAG, "No SMS app available to handle intent")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open SMS app: ${e.message}")
            false
        }
    }

    private fun openSMSAppBulk(phoneNumbers: List<String>, message: String): Boolean {
        return try {
            if (phoneNumbers.isEmpty()) {
                Log.e(TAG, "No phone numbers provided for bulk SMS")
                return false
            }
            
            // Try to open SMS app with multiple recipients
            val recipients = phoneNumbers.joinToString(";")
            val smsIntent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("smsto:$recipients")
                putExtra("sms_body", message)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            if (smsIntent.resolveActivity(packageManager) != null) {
                startActivity(smsIntent)
                Log.d(TAG, "Bulk SMS app opened for ${phoneNumbers.size} recipients")
                true
            } else {
                // Fallback: open with first recipient only
                openSMSApp(phoneNumbers.first(), message)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open bulk SMS app: ${e.message}")
            false
        }
    }
    
    private fun handleSOSIntent(intent: Intent?) {
        when {
            intent?.getBooleanExtra("trigger_automatic_sos", false) == true -> {
                Log.d(TAG, "MainActivity launched with automatic SOS trigger")
                // Notify Flutter to automatically start SOS process
                methodChannel?.invokeMethod("triggerAutomaticSOS", null)
            }
            intent?.getBooleanExtra("trigger_sos", false) == true -> {
                Log.d(TAG, "MainActivity launched with SOS trigger")
                // Notify Flutter about the SOS trigger
                methodChannel?.invokeMethod("triggerSOS", null)
            }
        }
    }

    private fun startPowerButtonService() {
        try {
            val serviceIntent = Intent(this, PowerButtonService::class.java)
            startForegroundService(serviceIntent)
            
            Log.d(TAG, "Power button service started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start power button service", e)
        }
    }

    private fun startNotificationService(userId: String?) {
        try {
            val serviceIntent = Intent(this, NotificationService::class.java)
            userId?.let { serviceIntent.putExtra("userId", it) }
            startForegroundService(serviceIntent)
            
            Log.d(TAG, "Notification service started with userId: $userId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start notification service", e)
        }
    }

    private fun stopNotificationService() {
        try {
            val serviceIntent = Intent(this, NotificationService::class.java)
            stopService(serviceIntent)
            
            Log.d(TAG, "Notification service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop notification service", e)
        }
    }
    
    private fun stopPowerButtonService() {
        try {
            val serviceIntent = Intent(this, PowerButtonService::class.java)
            stopService(serviceIntent)
            Log.d(TAG, "Power button service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop power button service", e)
        }
    }
    
    private fun triggerSOS() {
        Log.d(TAG, "SOS triggered from native")
        // The Flutter side will handle the main SOS functionality
        // This method is called when SOS is triggered via method channel
    }
}
