package com.levinencrypteduploader

import android.content.Context
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter

class GlobalRequestObserverDelegate(private val reactContext: ReactApplicationContext) {
    private val TAG = "UploadReceiver"

    // Upload events
    fun onUploadCompleted(context: Context, uploadInfo: UploadInfo) {
        // Handle completion if needed
    }

    fun onUploadError(context: Context, uploadInfo: UploadInfo, exception: Throwable) {
        val params = Arguments.createMap()
        params.putString("id", uploadInfo.uploadId)
        params.putString("error", exception.message ?: "Unknown exception")
        sendEvent("error", params, context)
    }

    fun onUploadProgress(context: Context, uploadInfo: UploadInfo) {
        val params = Arguments.createMap()
        params.putString("id", uploadInfo.uploadId)
        params.putInt("progress", uploadInfo.progressPercent)
        sendEvent("progress", params, context)
    }

    fun onUploadSuccess(context: Context, uploadInfo: UploadInfo, serverResponse: ServerResponse) {
        val headers = Arguments.createMap()
        serverResponse.headers.forEach { (key, value) ->
            headers.putString(key, value)
        }
        
        val params = Arguments.createMap()
        params.putString("id", uploadInfo.uploadId)
        params.putInt("responseCode", serverResponse.code)
        params.putString("responseBody", serverResponse.bodyString)
        params.putMap("responseHeaders", headers)
        sendEvent("completed", params, context)
    }

    // Download events
    fun onDownloadStarted(context: Context, downloadInfo: DownloadInfo) {
        val params = Arguments.createMap()
        params.putString("id", downloadInfo.downloadId)
        params.putString("path", downloadInfo.destinationPath)
        sendEvent("downloadStarted", params, context)
    }

    fun onDownloadProgress(context: Context, downloadInfo: DownloadInfo) {
        val params = Arguments.createMap()
        params.putString("id", downloadInfo.downloadId)
        params.putInt("progress", downloadInfo.progressPercent)
        params.putString("path", downloadInfo.destinationPath)
        sendEvent("downloadProgress", params, context)
    }

    fun onDownloadCompleted(context: Context, downloadInfo: DownloadInfo) {
        val params = Arguments.createMap()
        params.putString("id", downloadInfo.downloadId)
        params.putString("path", downloadInfo.destinationPath)
        sendEvent("downloadCompleted", params, context)
    }

    fun onDownloadError(context: Context, downloadInfo: DownloadInfo, exception: Throwable) {
        val params = Arguments.createMap()
        params.putString("id", downloadInfo.downloadId)
        params.putString("path", downloadInfo.destinationPath)
        params.putString("error", exception.message ?: "Unknown exception")
        sendEvent("downloadError", params, context)
    }

    private fun sendEvent(eventName: String, params: WritableMap?, context: Context) {
        reactContext.getJSModule(RCTDeviceEventEmitter::class.java)
            .emit("RNLevinEncryptedUploader-$eventName", params)
    }
}

// Data classes
data class UploadInfo(
    val uploadId: String,
    val progressPercent: Int
)

data class DownloadInfo(
    val downloadId: String,
    val destinationPath: String,
    val progressPercent: Int
)

data class ServerResponse(
    val code: Int,
    val bodyString: String,
    val headers: Map<String, String>
) 