package com.glowmatch.glowmatch

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fizardstudio.glowmatch/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidgetData") {
                val productName = call.argument<String>("productName") ?: "Semua produk aman ✨"
                val status = call.argument<String>("status") ?: "Tidak ada produk yang mendekati PAO."

                val prefs = getSharedPreferences("com.glowmatch.glowmatch.widget", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("product_name", productName)
                    putString("status", status)
                    apply()
                }

                // Trigger widget UI update
                ExpiryWidgetProvider.updateAllWidgets(this)

                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
