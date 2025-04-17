package com.levinencrypteduploader

import android.net.Uri
import android.webkit.MimeTypeMap
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import java.util.*
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

@ReactModule(name = LevinEncryptedUploaderModule.NAME)
class LevinEncryptedUploaderModule(reactContext: ReactApplicationContext) :
    NativeLevinEncryptedUploaderSpec(reactContext) {

    private val executor = Executors.newSingleThreadExecutor()
    private val uploadTasks = mutableMapOf<String, Any>()
    private val downloadTasks = mutableMapOf<String, Any>()

    override fun getName(): String {
        return NAME
    }

    override fun getFileInfo(path: String, promise: Promise) {
        try {
            val file = File(path)
            val exists = file.exists()
            val name = file.name
            val extension = name.substringAfterLast('.', "")
            val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "application/octet-stream"
            val size = if (exists) file.length() else 0

            val result = Arguments.createMap().apply {
                putString("mimeType", mimeType)
                putDouble("size", size.toDouble())
                putBoolean("exists", exists)
                putString("name", name)
                putString("extension", extension)
            }

            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("RN Uploader", e.message, e)
        }
    }

    override fun startUpload(options: ReadableMap, promise: Promise) {
        try {
            val url = options.getString("url") ?: throw Exception("URL is required")
            val path = options.getString("path") ?: throw Exception("Path is required")
            val method = options.getString("method") ?: "POST"
            val headers = options.getMap("headers")
            val encryption = options.getMap("encryption") ?: throw Exception("Encryption options are required")
            val key = encryption.getString("key") ?: throw Exception("Encryption key is required")
            val nonce = encryption.getString("nonce") ?: throw Exception("Encryption nonce is required")
            val customTransferId = options.getString("customTransferId")
            val appGroup = options.getString("appGroup")

            val taskId = customTransferId ?: UUID.randomUUID().toString()
            val file = File(path)
            if (!file.exists()) {
                throw Exception("File does not exist")
            }

            // TODO: Implement background upload with encryption
            // This is a simplified version that needs to be expanded
            executor.execute {
                try {
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    val keySpec = SecretKeySpec(Base64.getDecoder().decode(key), "AES")
                    val ivSpec = IvParameterSpec(Base64.getDecoder().decode(nonce))
                    cipher.init(Cipher.ENCRYPT_MODE, keySpec, ivSpec)

                    val inputStream = CipherInputStream(file.inputStream(), cipher)
                    val connection = URL(url).openConnection()
                    connection.doOutput = true
                    connection.requestMethod = method

                    headers?.let {
                        val iterator = it.keySetIterator()
                        while (iterator.hasNextKey()) {
                            val key = iterator.nextKey()
                            connection.setRequestProperty(key, it.getString(key))
                        }
                    }

                    connection.outputStream.use { output ->
                        inputStream.copyTo(output)
                    }

                    val responseCode = (connection as java.net.HttpURLConnection).responseCode
                    if (responseCode in 200..299) {
                        promise.resolve(taskId)
                    } else {
                        throw Exception("Upload failed with status code: $responseCode")
                    }
                } catch (e: Exception) {
                    promise.reject("RN Uploader", e.message, e)
                }
            }
        } catch (e: Exception) {
            promise.reject("RN Uploader", e.message, e)
        }
    }

    override fun cancelUpload(uploadId: String, promise: Promise) {
        try {
            val task = uploadTasks[uploadId]
            if (task != null) {
                // TODO: Implement cancellation logic
                uploadTasks.remove(uploadId)
                promise.resolve(true)
            } else {
                promise.reject("E_INVALID_ARGUMENT", "Invalid upload ID")
            }
        } catch (e: Exception) {
            promise.reject("RN Uploader", e.message, e)
        }
    }

    override fun startDownload(options: ReadableMap, promise: Promise) {
        try {
            val url = options.getString("url") ?: throw Exception("URL is required")
            val path = options.getString("path") ?: throw Exception("Path is required")
            val method = options.getString("method") ?: "GET"
            val headers = options.getMap("headers")
            val customTransferId = options.getString("customTransferId")
            val appGroup = options.getString("appGroup")

            val taskId = customTransferId ?: UUID.randomUUID().toString()

            // TODO: Implement background download
            // This is a simplified version that needs to be expanded
            executor.execute {
                try {
                    val connection = URL(url).openConnection()
                    connection.requestMethod = method

                    headers?.let {
                        val iterator = it.keySetIterator()
                        while (iterator.hasNextKey()) {
                            val key = iterator.nextKey()
                            connection.setRequestProperty(key, it.getString(key))
                        }
                    }

                    val responseCode = (connection as java.net.HttpURLConnection).responseCode
                    if (responseCode in 200..299) {
                        val file = File(path)
                        file.parentFile?.mkdirs()
                        connection.inputStream.use { input ->
                            file.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                        promise.resolve(taskId)
                    } else {
                        throw Exception("Download failed with status code: $responseCode")
                    }
                } catch (e: Exception) {
                    promise.reject("RN Uploader", e.message, e)
                }
            }
        } catch (e: Exception) {
            promise.reject("RN Uploader", e.message, e)
        }
    }

    override fun cancelDownload(downloadId: String, promise: Promise) {
        try {
            val task = downloadTasks[downloadId]
            if (task != null) {
                // TODO: Implement cancellation logic
                downloadTasks.remove(downloadId)
                promise.resolve(true)
            } else {
                promise.reject("E_INVALID_ARGUMENT", "Invalid download ID")
            }
        } catch (e: Exception) {
            promise.reject("RN Uploader", e.message, e)
        }
    }

    override fun downloadAndDecrypt(options: ReadableMap, promise: Promise) {
        try {
            val url = options.getString("url") ?: throw Exception("URL is required")
            val destination = options.getString("destination") ?: throw Exception("Destination is required")
            val headers = options.getMap("headers")
            val encryption = options.getMap("encryption") ?: throw Exception("Encryption options are required")
            val key = encryption.getString("key") ?: throw Exception("Encryption key is required")
            val nonce = encryption.getString("nonce") ?: throw Exception("Encryption nonce is required")

            executor.execute {
                try {
                    val connection = URL(url).openConnection()
                    connection.requestMethod = "GET"

                    headers?.let {
                        val iterator = it.keySetIterator()
                        while (iterator.hasNextKey()) {
                            val key = iterator.nextKey()
                            connection.setRequestProperty(key, it.getString(key))
                        }
                    }

                    val responseCode = (connection as java.net.HttpURLConnection).responseCode
                    if (responseCode in 200..299) {
                        val file = File(destination)
                        file.parentFile?.mkdirs()

                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        val keySpec = SecretKeySpec(Base64.getDecoder().decode(key), "AES")
                        val ivSpec = IvParameterSpec(Base64.getDecoder().decode(nonce))
                        cipher.init(Cipher.DECRYPT_MODE, keySpec, ivSpec)

                        connection.inputStream.use { input ->
                            CipherOutputStream(file.outputStream(), cipher).use { output ->
                                input.copyTo(output)
                            }
                        }

                        val result = Arguments.createMap().apply {
                            putString("path", destination)
                        }
                        promise.resolve(result)
                    } else {
                        throw Exception("Download failed with status code: $responseCode")
                    }
                } catch (e: Exception) {
                    promise.reject("RN Uploader", e.message, e)
                }
            }
        } catch (e: Exception) {
            promise.reject("RN Uploader", e.message, e)
        }
    }

    private fun sendEvent(eventName: String, params: WritableMap) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }

    companion object {
        const val NAME = "LevinEncryptedUploader"
    }
}
