package com.levinencrypteduploader

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import android.webkit.MimeTypeMap
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import net.gotev.uploadservice.UploadService
import net.gotev.uploadservice.UploadServiceConfig.httpStack
import net.gotev.uploadservice.UploadServiceConfig.initialize
import net.gotev.uploadservice.data.UploadNotificationConfig
import net.gotev.uploadservice.data.UploadNotificationStatusConfig
import net.gotev.uploadservice.observer.request.GlobalRequestObserver
import net.gotev.uploadservice.okhttp.OkHttpStack
import net.gotev.uploadservice.protocols.binary.BinaryUploadRequest
import okhttp3.OkHttpClient
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.UUID
import java.net.URL
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import java.util.Base64

@ReactModule(name = LevinEncryptedUploaderModule.NAME)
class LevinEncryptedUploaderModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val TAG = "LevinEncryptedUploader"
    private var notificationChannelID = "BackgroundUploadChannel"
    private var isGlobalRequestObserver = false
    private val eventEmitter = reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
    private val executor = Executors.newSingleThreadExecutor()
    private val downloadTasks = mutableMapOf<String, Any>()

    override fun getName(): String {
        return NAME
    }

    @ReactMethod
    fun getFileInfo(path: String, promise: Promise) {
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
            Log.e(TAG, "Error getting file info", e)
            promise.reject("E_FILE_INFO_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun startUpload(options: ReadableMap, promise: Promise) {
        try {
            val uploadUrl = options.getString("url") ?: throw IllegalArgumentException("URL is required")
            val filePath = options.getString("path") ?: throw IllegalArgumentException("File path is required")
            val method = options.getString("method") ?: "POST"
            val headers = options.getMap("headers")?.toHashMap() ?: HashMap<String, String>()
            val encryption = options.getMap("encryption") ?: throw IllegalArgumentException("Encryption parameters are required")
            val key = encryption.getString("key") ?: throw IllegalArgumentException("Encryption key is required")
            val nonce = encryption.getString("nonce") ?: throw IllegalArgumentException("Encryption nonce is required")

            Log.d(TAG, "Starting upload:")
            Log.d(TAG, "  ➤ URL: $uploadUrl")
            Log.d(TAG, "  ➤ File: $filePath")
            Log.d(TAG, "  ➤ Method: $method")
            Log.d(TAG, "  ➤ Has key: ${key.isNotEmpty()}")
            Log.d(TAG, "  ➤ Has nonce: ${nonce.isNotEmpty()}")

            val file = File(filePath)
            if (!file.exists()) {
                throw IllegalArgumentException("File does not exist: $filePath")
            }

            val application = reactApplicationContext.applicationContext as Application
            createNotificationChannel()
            initialize(application, notificationChannelID, false)

            if (!isGlobalRequestObserver) {
                isGlobalRequestObserver = true
                GlobalRequestObserver(application, GlobalRequestObserverDelegate(reactApplicationContext))
            }

            val request = BinaryUploadRequest(reactApplicationContext, uploadUrl)
                .setFileToUpload(filePath)
                .setMethod(method)
                .setEncryption(key, nonce)

            headers.forEach { (key, value) ->
                request.addHeader(key, value)
            }

            val uploadId = request.startUpload()
            promise.resolve(uploadId)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting upload", e)
            promise.reject("E_UPLOAD_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun cancelUpload(uploadId: String, promise: Promise) {
        try {
            UploadService.stopUpload(uploadId)
            promise.resolve(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling upload", e)
            promise.reject("E_CANCEL_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun startDownload(options: ReadableMap, promise: Promise) {
        try {
            val url = options.getString("url") ?: throw IllegalArgumentException("URL is required")
            val path = options.getString("path") ?: throw IllegalArgumentException("Path is required")
            val method = options.getString("method") ?: "GET"
            val headers = options.getMap("headers")
            val customTransferId = options.getString("customTransferId")
            val appGroup = options.getString("appGroup")

            val taskId = customTransferId ?: UUID.randomUUID().toString()

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
                    promise.reject("E_DOWNLOAD_ERROR", e.message, e)
                }
            }
        } catch (e: Exception) {
            promise.reject("E_DOWNLOAD_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun cancelDownload(downloadId: String, promise: Promise) {
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
            promise.reject("E_CANCEL_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun downloadAndDecrypt(options: ReadableMap, promise: Promise) {
        try {
            val url = options.getString("url") ?: throw IllegalArgumentException("URL is required")
            val destination = options.getString("destination") ?: throw IllegalArgumentException("Destination is required")
            val headers = options.getMap("headers")
            val encryption = options.getMap("encryption") ?: throw IllegalArgumentException("Encryption options are required")
            val key = encryption.getString("key") ?: throw IllegalArgumentException("Encryption key is required")
            val nonce = encryption.getString("nonce") ?: throw IllegalArgumentException("Encryption nonce is required")

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
                    promise.reject("E_DOWNLOAD_ERROR", e.message, e)
                }
            }
        } catch (e: Exception) {
            promise.reject("E_DOWNLOAD_ERROR", e.message, e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                notificationChannelID,
                "Background Upload Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = reactApplicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val NAME = "LevinEncryptedUploader"
    }
}

class GlobalRequestObserverDelegate(private val reactContext: ReactApplicationContext) : GlobalRequestObserver.Delegate {
    private val TAG = "UploadObserver"
    private val eventEmitter = reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)

    override fun onProgress(uploadId: String, progress: Int) {
        eventEmitter.emit("levin-encrypted-uploader-progress", Arguments.createMap().apply {
            putString("id", uploadId)
            putDouble("progress", progress.toDouble())
        })
    }

    override fun onCompleted(uploadId: String, responseCode: Int, responseBody: String) {
        eventEmitter.emit("levin-encrypted-uploader-completed", Arguments.createMap().apply {
            putString("id", uploadId)
            putInt("responseCode", responseCode)
            putString("responseBody", responseBody)
        })
    }

    override fun onError(uploadId: String, exception: Throwable) {
        eventEmitter.emit("levin-encrypted-uploader-error", Arguments.createMap().apply {
            putString("id", uploadId)
            putString("error", exception.message)
        })
    }

    override fun onCancelled(uploadId: String) {
        eventEmitter.emit("levin-encrypted-uploader-cancelled", Arguments.createMap().apply {
            putString("id", uploadId)
        })
    }
}
