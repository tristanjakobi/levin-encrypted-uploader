package com.levinencrypteduploader

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter

class NotificationActionsReceiver : BroadcastReceiver() {
    private val TAG = "NotificationActReceiver"
    private var reactContext: ReactApplicationContext? = null

    fun setReactContext(context: ReactApplicationContext) {
        reactContext = context
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null || intent.action != NotificationActions.INTENT_ACTION) {
            return
        }

        when (intent.getStringExtra(NotificationActions.PARAM_ACTION)) {
            NotificationActions.ACTION_CANCEL_UPLOAD -> {
                val uploadId = intent.getStringExtra(NotificationActions.PARAM_UPLOAD_ID)
                if (uploadId != null) {
                    onUserRequestedUploadCancellation(context!!, uploadId)
                }
            }
            NotificationActions.ACTION_CANCEL_DOWNLOAD -> {
                val downloadId = intent.getStringExtra(NotificationActions.PARAM_DOWNLOAD_ID)
                if (downloadId != null) {
                    onUserRequestedDownloadCancellation(context!!, downloadId)
                }
            }
            NotificationActions.ACTION_OPEN_DOWNLOAD -> {
                val downloadId = intent.getStringExtra(NotificationActions.PARAM_DOWNLOAD_ID)
                if (downloadId != null) {
                    onUserRequestedOpenDownload(context!!, downloadId)
                }
            }
        }
    }

    private fun onUserRequestedUploadCancellation(context: Context, uploadId: String) {
        Log.e("CANCEL_UPLOAD", "User requested cancellation of upload with ID: $uploadId")
        // TODO: Implement upload cancellation
        val params = Arguments.createMap()
        params.putString("id", uploadId)
        sendEvent("cancelled", params, context)
    }

    private fun onUserRequestedDownloadCancellation(context: Context, downloadId: String) {
        Log.e("CANCEL_DOWNLOAD", "User requested cancellation of download with ID: $downloadId")
        // TODO: Implement download cancellation
        val params = Arguments.createMap()
        params.putString("id", downloadId)
        sendEvent("downloadCancelled", params, context)
    }

    private fun onUserRequestedOpenDownload(context: Context, downloadId: String) {
        Log.e("OPEN_DOWNLOAD", "User requested to open download with ID: $downloadId")
        // TODO: Implement opening downloaded file
        val params = Arguments.createMap()
        params.putString("id", downloadId)
        sendEvent("downloadOpened", params, context)
    }

    private fun sendEvent(eventName: String, params: WritableMap?, context: Context) {
        reactContext?.getJSModule(RCTDeviceEventEmitter::class.java)
            ?.emit("RNLevinEncryptedUploader-$eventName", params)
            ?: Log.e(TAG, "sendEvent() failed due reactContext == null!")
    }
} 