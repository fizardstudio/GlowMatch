package com.glowmatch.glowmatch

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fizardstudio.glowmatch/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.glowmatch.glowmatch/camera_view",
            GlowMatchCameraViewFactory(flutterEngine.dartExecutor.binaryMessenger, this)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
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
                }
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "glowmatch_look_${System.currentTimeMillis()}"
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"
                    if (bytes != null) {
                        val success = saveImageToGallery(bytes, filename, mimeType)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Bytes cannot be null", null)
                    }
                }
                "shareImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "glowmatch_share_${System.currentTimeMillis()}"
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"
                    if (bytes != null) {
                        val success = shareImage(bytes, filename, mimeType)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Bytes cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveImageToGallery(bytes: ByteArray, filename: String, mimeType: String): Boolean {
        return try {
            val extension = if (mimeType == "image/gif") "gif" else "png"
            val contentValues = android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, "$filename.$extension")
                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, android.os.Environment.DIRECTORY_PICTURES + "/GlowMatch")
            }

            val resolver = contentResolver
            val uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

            if (uri != null) {
                resolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(bytes)
                    outputStream.flush()
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun shareImage(bytes: ByteArray, filename: String, mimeType: String): Boolean {
        return try {
            val extension = if (mimeType == "image/gif") "gif" else "png"
            val contentValues = android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, "$filename.$extension")
                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, android.os.Environment.DIRECTORY_PICTURES + "/GlowMatch")
            }

            val resolver = contentResolver
            val uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

            if (uri != null) {
                resolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(bytes)
                    outputStream.flush()
                }
                
                val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(android.content.Intent.EXTRA_STREAM, uri)
                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                val chooser = android.content.Intent.createChooser(intent, "Bagikan GlowCard")
                chooser.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(chooser)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
