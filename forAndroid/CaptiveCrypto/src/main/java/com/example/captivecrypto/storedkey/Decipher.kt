// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.security.keystore.KeyProperties
import java.security.Key
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.OAEPParameterSpec

fun decipherWithStoredKey(
    encipheredMessage: EncipheredMessage,
    alias: String,
    providerName: String = KEY.AndroidKeyStore.name
): String
{
    val keyStore = loadKeyStore(providerName)
    val entry = keyStore.getEntry(alias, null)
    val key: Key = when(entry) {
        // Decipher with the private key.
        is KeyStore.PrivateKeyEntry -> entry.privateKey

        is KeyStore.SecretKeyEntry -> entry.secretKey

        else -> throw Exception(listOf(
            "Cannot decipher with stored item \"${alias}\".",
            " Summary of entry:${entry}."
        ).joinToString(""))
    }
    return decipher(encipheredMessage, key)
}

private fun decipher(encipheredMessage: EncipheredMessage, key: Key):String {
    // Next statement creates a parameter specification object. In this
    // version, assumptions are made, about block mode, RSA digest and
    // padding for example. In an ideal version, those parameters would
    // be deduced from the key entry, or would be passed in to this
    // function maybe.
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
        // If there are no digest algorithms in common between the
        // OAEPParameterSpec and the key, you get this exception ...
        // java.security.InvalidKeyException: Keystore operation failed
        // ... with this cause
        // android.security.KeyStoreException: Incompatible digest

        // For AES, an IV is needed. It will have been created at or
        // before encipherment time.

        // In CBC mode, only the IV need be specified. In GCM mode, the tag id
        // length must also be specified.

        // In CBC mode, if you don't set an IV spec, you get this:
        //
        //     java.lang.RuntimeException:
        //     java.security.InvalidAlgorithmParameterException:
        //     IV must be specified in CBC mode

        // For IvParameterSpec, TOTH:
        // https://medium.com/@hakkitoklu/aes256-encryption-decryption-in-android-2fae6938fc2b
        // val parameterSpec = IvParameterSpec(cipher.iv)

        // For GCMParameterSpec, TOTH:
        // https://medium.com/@josiassena/using-the-android-keystore-system-to-store-sensitive-information-3a56175a454b
        KeyProperties.KEY_ALGORITHM_AES ->
            GCMParameterSpec(128, encipheredMessage.iv)

        else -> throw Exception(listOf(
            "Cannot decipher with key \"${key.description}\".",
            " Unsupported algorithm: \"${key.algorithm}\"."
        ).joinToString(""))
    }

    val cipher = Cipher.getInstance(cipherSpecifier(key))

    cipher.init(Cipher.DECRYPT_MODE, key, parameterSpec)
    return String(cipher.doFinal(
        encipheredMessage.ciphertext), Charsets.UTF_8)
}