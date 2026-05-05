package com.example.tpe_qr_saas

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "quick_sell_pay/whatsapp_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            if (call.method == "shareProducts") {
                handleShareProducts(call, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleShareProducts(call: MethodCall, result: MethodChannel.Result) {
        val rawImagePaths = call.argument<List<String>>("imagePaths")
        if (rawImagePaths.isNullOrEmpty()) {
            result.error("empty_items", "Aucun produit selectionne", null)
            return
        }

        val imageUris = rawImagePaths.mapNotNull { imagePath ->
            val imageFile = File(imagePath)
            if (!imageFile.exists()) {
                null
            } else {
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    imageFile
                )
            }
        }

        if (imageUris.isEmpty()) {
            result.error("invalid_items", "Impossible de preparer les produits a partager", null)
            return
        }

        val caption = call.argument<String>("caption") ?: ""

        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "image/*"
            `package` = "com.whatsapp"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList<Uri>(imageUris))
            putExtra(Intent.EXTRA_TEXT, caption)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(intent)
            result.success(true)
        } catch (error: ActivityNotFoundException) {
            result.error(
                "whatsapp_not_found",
                "WhatsApp n est pas installe sur cet appareil",
                null
            )
        } catch (error: Exception) {
            result.error(
                "share_failed",
                error.message ?: "Partage WhatsApp impossible",
                null
            )
        }
    }
}
