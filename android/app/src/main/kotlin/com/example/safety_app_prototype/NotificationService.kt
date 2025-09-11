package com.example.safety_app_prototype

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.ValueEventListener
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.FirebaseApp
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.PowerManager
import android.os.Handler
import android.os.Looper

class NotificationService : Service() {

    companion object {
        private const val TAG = "NotificationService"
        private const val CHANNEL_ID = "emergency_notifications"
        private const val FOREGROUND_CHANNEL_ID = "notification_service"
        private const val NOTIFICATION_ID = 1001
        private const val FOREGROUND_NOTIFICATION_ID = 1002
        private const val PREFS_NAME = "notification_service_prefs"
        private const val KEY_USER_ID = "user_id"
    }

    private lateinit var database: FirebaseDatabase
    private lateinit var auth: FirebaseAuth
    private var notificationListener: ValueEventListener? = null
    private var databaseReference: DatabaseReference? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var sharedPreferences: SharedPreferences? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isServiceRunning = false

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "NotificationService created")
        
        isServiceRunning = true
        sharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        // Acquire wake lock to keep service alive
        acquireWakeLock()
        
        // Initialize Firebase
        initializeFirebase()
        
        createNotificationChannels()
        startForeground(FOREGROUND_NOTIFICATION_ID, createForegroundNotification())
        
        // Delay Firebase listener setup to ensure Firebase is initialized
        handler.postDelayed({
            if (isServiceRunning) {
                setupFirebaseListener()
            }
        }, 2000)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "NotificationService started with intent: ${intent?.action}")
        
        // Handle different actions
        when (intent?.action) {
            "STOP_SERVICE" -> {
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // Store user ID if provided
                intent?.getStringExtra("userId")?.let { userId ->
                    sharedPreferences?.edit()?.putString(KEY_USER_ID, userId)?.apply()
                    Log.d(TAG, "Stored user ID for notifications: $userId")
                }
            }
        }
        
        return START_STICKY // Restart service if killed
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "NotificationService destroyed")
        isServiceRunning = false
        cleanupListener()
        releaseWakeLock()
    }

    private fun initializeFirebase() {
        try {
            // Initialize Firebase if not already initialized
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
            }
            // Initialize Firebase Realtime Database with specific URL
            database = FirebaseDatabase.getInstance("https://safety-app-487c6-default-rtdb.firebaseio.com")
            auth = FirebaseAuth.getInstance()
            Log.d(TAG, "Firebase initialized successfully with database URL")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Firebase", e)
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$TAG::NotificationServiceWakeLock"
            ).apply {
                acquire(10 * 60 * 1000L) // 10 minutes timeout
            }
            Log.d(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "Wake lock released")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock", e)
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Emergency notifications channel
            val emergencyChannel = NotificationChannel(
                CHANNEL_ID, 
                "Emergency Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for emergency situations"
                enableVibration(true)
                enableLights(true)
                setBypassDnd(true)
            }
            
            // Foreground service channel
            val serviceChannel = NotificationChannel(
                FOREGROUND_CHANNEL_ID,
                "Notification Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background notification listening service"
                enableVibration(false)
                enableLights(false)
            }
            
            notificationManager.createNotificationChannel(emergencyChannel)
            notificationManager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createForegroundNotification() =
        NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setContentTitle("Safety App - Background Service")
            .setContentText("Listening for emergency notifications...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

    private fun setupFirebaseListener() {
        // Try to get user ID from current auth or stored preferences
        val userId = auth.currentUser?.uid ?: sharedPreferences?.getString(KEY_USER_ID, null)
        
        if (userId == null) {
            Log.w(TAG, "No user ID available, retrying in 5 seconds...")
            handler.postDelayed({
                if (isServiceRunning) {
                    setupFirebaseListener()
                }
            }, 5000)
            return
        }

        Log.d(TAG, "Setting up Firebase listener for user: $userId")
        databaseReference = database.getReference("notifications").child(userId)
        
        notificationListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                Log.d(TAG, "Notification data changed for user: $userId")
                
                for (childSnapshot in snapshot.children) {
                    val senderId = childSnapshot.key ?: continue
                    val data = childSnapshot.value as? Map<String, Any> ?: continue
                    
                    val message = data["message"] as? String ?: continue
                    val senderName = data["senderName"] as? String ?: "Unknown"
                    val type = data["type"] as? String ?: "general"
                    val isRead = data["isRead"] as? Boolean ?: false
                    val timestamp = data["timestamp"] as? Long ?: System.currentTimeMillis()
                    
                    // Only show notification if not read and recent (within last 5 minutes)
                    val fiveMinutesAgo = System.currentTimeMillis() - (5 * 60 * 1000)
                    if (!isRead && timestamp > fiveMinutesAgo) {
                        showEmergencyNotification(senderName, message, type, senderId)
                    }
                }
            }

            override fun onCancelled(error: DatabaseError) {
                Log.e(TAG, "Firebase listener cancelled: ${error.message}")
            }
        }

        databaseReference?.addValueEventListener(notificationListener!!)
        Log.d(TAG, "Firebase listener setup for user: $userId")
    }

    private fun showEmergencyNotification(
        senderName: String, 
        message: String, 
        type: String,
        senderId: String
    ) {
        val title = when (type) {
            "emergency" -> "🚨 Emergency Alert"
            "location_share" -> "📍 Location Update"
            else -> "📱 Safety Notification"
        }
        
        // Create intent to open the app when notification is tapped
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("notification_type", type)
            putExtra("sender_id", senderId)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("From $senderName: $message")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setContentIntent(pendingIntent)
            .build()

        try {
            val notificationManager = NotificationManagerCompat.from(this)
            val notificationId = senderId.hashCode()
            notificationManager.notify(notificationId, notification)
            
            Log.d(TAG, "Emergency notification displayed: $title - $message")
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied for showing notification", e)
        }
    }

    private fun cleanupListener() {
        notificationListener?.let { listener ->
            databaseReference?.removeEventListener(listener)
        }
        notificationListener = null
        databaseReference = null
    }
}