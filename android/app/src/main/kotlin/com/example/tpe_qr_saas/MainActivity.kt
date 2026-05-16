package com.example.tpe_qr_saas

import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.app.PendingIntent
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val shareChannelName = "quick_sell_pay/whatsapp_share"
    private val printerChannelName = "quick_sell_pay/xprinter_usb"
    private val usbPermissionAction = "com.example.tpe_qr_saas.USB_PERMISSION"
    private var pendingUsbPrint: PendingUsbPrint? = null
    private var usbReceiverRegistered = false
    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != usbPermissionAction) return
            val pending = pendingUsbPrint ?: return
            pendingUsbPrint = null
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            if (!granted) {
                pending.result.error(
                    "usb_permission_denied",
                    "Permission USB refusee pour ${pending.device.deviceName}",
                    null
                )
                return
            }
            printUsb(pending.device, pending.bytes, pending.result)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannelName
        ).setMethodCallHandler { call, result ->
            if (call.method == "shareProducts") {
                handleShareProducts(call, result)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            printerChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listPrinters" -> result.success(listUsbPrinters())
                "print" -> handleUsbPrint(call, result)
                else -> result.notImplemented()
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

    override fun onDestroy() {
        if (usbReceiverRegistered) {
            unregisterReceiver(usbPermissionReceiver)
            usbReceiverRegistered = false
        }
        super.onDestroy()
    }

    private fun listUsbPrinters(): List<Map<String, Any?>> {
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        return manager.deviceList.values
            .filter { device -> findWritableEndpoint(device) != null }
            .map { device ->
                mapOf(
                    "name" to productName(device),
                    "deviceId" to device.deviceId,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId
                )
            }
    }

    private fun handleUsbPrint(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.isEmpty()) {
            result.error("empty_bytes", "Aucune donnee a imprimer", null)
            return
        }

        val device = findUsbDevice(
            call.argument<Int>("deviceId"),
            call.argument<Int>("vendorId"),
            call.argument<Int>("productId")
        )
        if (device == null) {
            result.error("usb_not_found", "Imprimante USB introuvable", null)
            return
        }

        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        if (manager.hasPermission(device)) {
            printUsb(device, bytes, result)
            return
        }

        registerUsbReceiver()
        pendingUsbPrint = PendingUsbPrint(device, bytes, result)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        val permissionIntent = PendingIntent.getBroadcast(
            this,
            0,
            Intent(usbPermissionAction).setPackage(packageName),
            flags
        )
        manager.requestPermission(device, permissionIntent)
    }

    private fun registerUsbReceiver() {
        if (usbReceiverRegistered) return
        val filter = IntentFilter(usbPermissionAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbPermissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbPermissionReceiver, filter)
        }
        usbReceiverRegistered = true
    }

    private fun findUsbDevice(deviceId: Int?, vendorId: Int?, productId: Int?): UsbDevice? {
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        return manager.deviceList.values.firstOrNull { device ->
            if (deviceId != null && device.deviceId == deviceId) {
                true
            } else {
                vendorId != null &&
                    productId != null &&
                    device.vendorId == vendorId &&
                    device.productId == productId
            }
        }
    }

    private fun printUsb(device: UsbDevice, bytes: ByteArray, result: MethodChannel.Result) {
        val target = findWritableEndpoint(device)
        if (target == null) {
            result.error("usb_endpoint_missing", "Aucun endpoint USB compatible trouve", null)
            return
        }

        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        var connection: UsbDeviceConnection? = null
        try {
            connection = manager.openDevice(device)
            if (connection == null) {
                result.error("usb_open_failed", "Connexion USB impossible", null)
                return
            }
            if (!connection.claimInterface(target.usbInterface, true)) {
                result.error("usb_claim_failed", "Interface USB indisponible", null)
                return
            }

            var offset = 0
            while (offset < bytes.size) {
                val size = minOf(target.endpoint.maxPacketSize.coerceAtLeast(64), bytes.size - offset)
                val chunk = bytes.copyOfRange(offset, offset + size)
                val written = connection.bulkTransfer(target.endpoint, chunk, chunk.size, 5000)
                if (written <= 0) {
                    result.error("usb_write_failed", "Ecriture USB interrompue", null)
                    return
                }
                offset += written
            }
            result.success(true)
        } catch (error: Exception) {
            result.error("usb_print_failed", error.message ?: "Impression USB impossible", null)
        } finally {
            try {
                target?.let { connection?.releaseInterface(it.usbInterface) }
            } catch (_: Exception) {
            }
            connection?.close()
        }
    }

    private fun findWritableEndpoint(device: UsbDevice): UsbTarget? {
        for (interfaceIndex in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(interfaceIndex)
            for (endpointIndex in 0 until usbInterface.endpointCount) {
                val endpoint = usbInterface.getEndpoint(endpointIndex)
                val writable = endpoint.direction == UsbConstants.USB_DIR_OUT &&
                    endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK
                if (writable) {
                    return UsbTarget(usbInterface, endpoint)
                }
            }
        }
        return null
    }

    private fun productName(device: UsbDevice): String {
        val product = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                device.productName
            } else {
                null
            }
        } catch (_: SecurityException) {
            null
        }
        return product ?: "XPrinter USB"
    }

    private data class UsbTarget(
        val usbInterface: UsbInterface,
        val endpoint: UsbEndpoint
    )

    private data class PendingUsbPrint(
        val device: UsbDevice,
        val bytes: ByteArray,
        val result: MethodChannel.Result
    )
}
