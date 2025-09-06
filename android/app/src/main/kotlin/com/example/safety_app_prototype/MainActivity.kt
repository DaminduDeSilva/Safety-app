package com.example.safety_app_prototype

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "power_button_service"
    }
    
    private var powerButtonService: PowerButtonService? = null
    private var methodChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
