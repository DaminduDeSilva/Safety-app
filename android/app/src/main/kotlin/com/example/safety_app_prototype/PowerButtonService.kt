package com.example.safety_app_prototype

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class PowerButtonService : Service() {
    
    companion object {
        private const val TAG = "PowerButtonService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "power_button_service_channel"
        private const val MAX_PRESS_COUNT = 5
        private const val PRESS_TIME_WINDOW = 3000L // 3 seconds
        
        // Static reference to allow communication from service to activity
        var instance: PowerButtonService? = null
        var methodChannel: MethodChannel? = null
    }
    
    private var powerButtonReceiver: PowerButtonReceiver? = null
    private var pressCount = 0
    private var firstPressTime = 0L
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "PowerButtonService created")
        createNotificationChannel()
        registerPowerButtonReceiver()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "PowerButtonService started")
        startForeground(NOTIFICATION_ID, createNotification())
        return START_STICKY // Restart if killed
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "PowerButtonService destroyed")
        unregisterPowerButtonReceiver()
        instance = null
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Safety App Emergency Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors power button for emergency SOS"
                setShowBadge(false)
                setSound(null, null)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Safety App Active")
            .setContentText("Press power button 5 times for emergency SOS")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
    
    private fun registerPowerButtonReceiver() {
        powerButtonReceiver = PowerButtonReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        }
        registerReceiver(powerButtonReceiver, filter)
        Log.d(TAG, "Power button receiver registered")
    }
    
    private fun unregisterPowerButtonReceiver() {
        powerButtonReceiver?.let {
            unregisterReceiver(it)
            powerButtonReceiver = null
            Log.d(TAG, "Power button receiver unregistered")
        }
    }
    
    private fun onPowerButtonPressed() {
        val currentTime = System.currentTimeMillis()
        
        // Reset count if outside time window
        if (currentTime - firstPressTime > PRESS_TIME_WINDOW) {
            pressCount = 1
            firstPressTime = currentTime
            Log.d(TAG, "Power button press count reset: $pressCount")
        } else {
            pressCount++
            Log.d(TAG, "Power button press count: $pressCount")
        }
        
        // Check if we've reached the required number of presses
        if (pressCount >= MAX_PRESS_COUNT) {
            Log.d(TAG, "$pressCount power button presses detected - triggering SOS")
            triggerSOS()
            // Don't reset count immediately - let it continue triggering for more presses
            // Only reset after time window expires
        }
    }
    
    private fun resetPressCount() {
        pressCount = 0
        firstPressTime = 0L
    }

    private fun triggerSOS() {
        // Launch the app and trigger automatic SOS
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("trigger_automatic_sos", true)
        }
        startActivity(intent)
        
        // Also try to trigger via method channel if available
        methodChannel?.invokeMethod("triggerAutomaticSOS", null)
        
        Log.d(TAG, "SOS triggered from power button service - launching app for automatic SOS")
    }

    inner class PowerButtonReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "Screen turned off - power button pressed")
                    onPowerButtonPressed()
                }
                Intent.ACTION_SCREEN_ON -> {
                    Log.d(TAG, "Screen turned on")
                    // We could also count screen on events, but screen off is more reliable
                    // for detecting power button presses
                }
            }
        }
    }
}
