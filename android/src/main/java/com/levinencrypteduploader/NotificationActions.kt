package com.levinencrypteduploader

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

class NotificationActions {
    companion object {
        const val INTENT_ACTION = "com.levinencrypteduploader.notification.action"
        const val PARAM_ACTION = "action"
        const val PARAM_UPLOAD_ID = "uploadId"
        const val PARAM_DOWNLOAD_ID = "downloadId"
        const val ACTION_CANCEL_UPLOAD = "cancelUpload"
        const val ACTION_CANCEL_DOWNLOAD = "cancelDownload"
        const val ACTION_OPEN_DOWNLOAD = "openDownload"
    }

    fun getCancelUploadAction(
        context: Context?,
        requestCode: Int,
        uploadID: String?
    ): PendingIntent? {
        val intent = Intent(INTENT_ACTION)
        intent.putExtra(PARAM_ACTION, ACTION_CANCEL_UPLOAD)
        intent.putExtra(PARAM_UPLOAD_ID, uploadID)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun getCancelDownloadAction(
        context: Context?,
        requestCode: Int,
        downloadID: String?
    ): PendingIntent? {
        val intent = Intent(INTENT_ACTION)
        intent.putExtra(PARAM_ACTION, ACTION_CANCEL_DOWNLOAD)
        intent.putExtra(PARAM_DOWNLOAD_ID, downloadID)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun getOpenDownloadAction(
        context: Context?,
        requestCode: Int,
        downloadID: String?
    ): PendingIntent? {
        val intent = Intent(INTENT_ACTION)
        intent.putExtra(PARAM_ACTION, ACTION_OPEN_DOWNLOAD)
        intent.putExtra(PARAM_DOWNLOAD_ID, downloadID)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
} 