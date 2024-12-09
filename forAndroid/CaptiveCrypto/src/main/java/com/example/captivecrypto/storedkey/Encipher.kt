// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.security.keystore.KeyProperties
import kotlinx.serialization.Serializable
import java.security.Key
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec

@Serializable
data class EncipheredMessage(
    val ciphertext:ByteArray,
    val iv:ByteArray?,
    val provider:String,
    val algorithm: String,
    val digest: String?
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as EncipheredMessage

        if (!ciphertext.contentEquals(other.ciphertext)) return false
        if (iv != null) {
            if (other.iv == null) return false
            if (!iv.contentEquals(other.iv)) return false
        } else if (other.iv != null) return false
        if (provider != other.provider) return false
        if (algorithm != other.algorithm) return false
        if (digest != other.digest) return false

        return true
    }

    override fun hashCode(): Int {
        var result = ciphertext.contentHashCode()
        result = 31 * result + (iv?.contentHashCode() ?: 0)
        result = 31 * result + provider.hashCode()
        result = 31 * result + algorithm.hashCode()
        result = 31 * result + (digest?.hashCode() ?: 0)
        return result
    }
}

fun encipherWithStoredKey(
    plaintext: String,
    alias: String,
    providerName: String = KEY.AndroidKeyStore.name
): EncipheredMessage
{
    val keyStore = loadKeyStore(providerName)
    val key = when(val entry = keyStore.getEntry(alias, null)) {
        is KeyStore.PrivateKeyEntry ->
            // Encipher with the public key. The public key isn't stored
            // as a key; it is stored in a certificate that is created
            // by the creation of the private key.
            keyStore.getCertificate(alias).publicKey

        is KeyStore.SecretKeyEntry -> entry.secretKey

        else -> throw Exception(listOf(
            "Cannot encipher with stored item \"${alias}\".",
            " Summary of entry:${entry}."
        ).joinToString(""))
    }

    return encipher(plaintext, key)
}

private fun encipher(plaintext: String, key: Key): EncipheredMessage {
    val parameterSpec = when(key.algorithm) {

        // For RSA: Create a parameter specification based on the
        // default but changing the digest algorithm to SHA-512. The
        // default would be SHA-1, which is generally deprecated.
        KeyProperties.KEY_ALGORITHM_RSA -> OAEPParameterSpec(
            KeyProperties.DIGEST_SHA512,
            OAEPParameterSpec.DEFAULT.mgfAlgorithm,
            OAEPParameterSpec.DEFAULT.mgfParameters,
            OAEPParameterSpec.DEFAULT.pSource
        )

        // For AES: Don't specify an IV so a random one will be generated.
        KeyProperties.KEY_ALGORITHM_AES -> null

        else -> throw Exception(listOf(
            "Cannot encipher with key \"${key.description}\".",
            " Unsupported algorithm: \"${key.algorithm}\"."
        ).joinToString(""))
    }

    val cipher = Cipher.getInstance(cipherSpecifier(key))

    cipher.init(Cipher.ENCRYPT_MODE, key, parameterSpec)
    val encipheredBytes = cipher.doFinal(
        plaintext.toByteArray(Charsets.UTF_8))

    return EncipheredMessage(
        encipheredBytes,
        cipher.iv,
        cipher.provider.name,
        cipher.algorithm,
        (parameterSpec as? OAEPParameterSpec)?.digestAlgorithm
    )
}
