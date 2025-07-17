package com.mt.walkzilla

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var initialStepCount: Int = -1
    private var lastStepCount: Int = 0

    companion object {
        private const val METHOD_CHANNEL = "walkzilla/step_counter"
        private const val EVENT_CHANNEL = "walkzilla/step_stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize sensor manager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        // Method channel for starting/stopping step counter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startStepCounter" -> {
                        if (stepSensor != null) {
                            sensorManager.registerListener(this, stepSensor, SensorManager.SENSOR_DELAY_NORMAL)
                            result.success(true)
                        } else {
                            result.error("SENSOR_UNAVAILABLE", "Step Counter sensor not available on this device", null)
                        }
                    }
                    "stopStepCounter" -> {
                        sensorManager.unregisterListener(this)
                        result.success(true)
                    }
                    "getSensorAvailability" -> {
                        result.success(stepSensor != null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Event channel for real-time step updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    // Send initial availability status
                    events?.success(mapOf(
                        "type" to "sensor_status",
                        "available" to (stepSensor != null)
                    ))
                }

                override fun onCancel(arguments: Any?) {
                    sensorManager.unregisterListener(this@MainActivity)
                    eventSink = null
                }
            })
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_STEP_COUNTER) {
            val totalSteps = event.values[0].toInt()
            
            // Initialize baseline on first reading
            if (initialStepCount == -1) {
                initialStepCount = totalSteps
                lastStepCount = 0
            }
            
            // Calculate steps since app started
            val stepsSinceStart = totalSteps - initialStepCount
            
            // Only send updates if steps have changed
            if (stepsSinceStart != lastStepCount) {
                lastStepCount = stepsSinceStart
                
                eventSink?.success(mapOf(
                    "type" to "step_update",
                    "totalSteps" to totalSteps,
                    "stepsSinceStart" to stepsSinceStart,
                    "timestamp" to System.currentTimeMillis()
                ))
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Handle accuracy changes if needed
    }

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
    }
} 