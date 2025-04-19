package com.levinencrypteduploader

import android.util.Log
import java.io.InputStream
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class EncryptedInputStream(
    private val inputStream: InputStream,
    private val key: String,
    private val nonce: String
) : InputStream() {
    private val TAG = "EncryptedInputStream"
    private val cipher: Cipher
    private val cipherInputStream: CipherInputStream

    init {
        try {
            Log.d(TAG, "Initializing EncryptedInputStream")
            Log.d(TAG, "  ➤ Key length: ${key.length}")
            Log.d(TAG, "  ➤ Nonce length: ${nonce.length}")

            val keyBytes = Base64.getDecoder().decode(key)
            val nonceBytes = Base64.getDecoder().decode(nonce)

            val keySpec = SecretKeySpec(keyBytes, "AES")
            val parameterSpec = GCMParameterSpec(128, nonceBytes)

            cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, parameterSpec)
            cipherInputStream = CipherInputStream(inputStream, cipher)

            Log.d(TAG, "EncryptedInputStream initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing EncryptedInputStream", e)
            throw e
        }
    }

    override fun read(): Int {
        return cipherInputStream.read()
    }

    override fun read(b: ByteArray): Int {
        return cipherInputStream.read(b)
    }

    override fun read(b: ByteArray, off: Int, len: Int): Int {
        return cipherInputStream.read(b, off, len)
    }

    override fun available(): Int {
        return cipherInputStream.available()
    }

    override fun close() {
        Log.d(TAG, "Closing EncryptedInputStream")
        cipherInputStream.close()
        inputStream.close()
    }
} 