package com.bluebubbles.messaging.services.system

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/// Saves a file to the public Downloads folder without broad storage access.
class SaveFileToDownloadsHandler : MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "save-file-to-downloads"
    }

    override fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, context: Context) {
        val filePath = call.argument<String>("filePath")
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

        if (filePath.isNullOrBlank() || fileName.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "filePath and fileName are required", null)
            return
        }

        var pendingUri: Uri? = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                pendingUri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("MediaStore.Downloads insert returned no URI")

                resolver.openOutputStream(pendingUri)?.use { outputStream ->
                    FileInputStream(filePath).use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                } ?: throw IllegalStateException("Unable to open the Downloads output stream")

                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(pendingUri, values, null, null)
                result.success(pendingUri.toString())
            } else {
                @Suppress("DEPRECATION")
                val destinationDirectory =
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                destinationDirectory.mkdirs()
                val destination = File(destinationDirectory, fileName)
                File(filePath).copyTo(destination, overwrite = true)
                result.success(destination.absolutePath)
            }
        } catch (exception: Exception) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                pendingUri?.let { context.contentResolver.delete(it, null, null) }
            }
            result.error("SAVE_FAILED", exception.message, null)
        }
    }
}
