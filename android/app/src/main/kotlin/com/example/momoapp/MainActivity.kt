package com.example.momoapp

import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.momoapp/sms"
    private val TAG = "SMSReader"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSmsMessages" -> {
                    try {
                        val messages = readSMS()
                        Log.d(TAG, "Found ${messages.size} messages")
                        result.success(messages)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error reading SMS", e)
                        result.error("SMS_READ_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readSMS(): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        
        try {
            // Get all messages without filter
            val cursor: Cursor? = contentResolver.query(
                Uri.parse("content://sms/inbox"),
                arrayOf("body", "date", "address"),
                null, 
                null,
                "date DESC"
            )

            cursor?.use {
                Log.d(TAG, "Total SMS messages in inbox: ${it.count}")
                
                while (it.moveToNext()) {
                    val body = it.getString(0)
                    val date = it.getLong(1)
                    val address = it.getString(2)
                    
                    // Filter M-Money transaction messages
                    if (address == "M-Money" && 
                        (body.contains("transferred to", ignoreCase = true) ||
                         body.contains("payment of", ignoreCase = true) ||
                         body.contains("received", ignoreCase = true))) {
                            
                        messages.add(mapOf(
                            "body" to body,
                            "date" to date,
                            "address" to address
                        ))
                        Log.d(TAG, "Added M-Money transaction: $body")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading SMS", e)
            throw e
        }

        Log.d(TAG, "Found ${messages.size} M-Money transactions")
        return messages
    }
}
