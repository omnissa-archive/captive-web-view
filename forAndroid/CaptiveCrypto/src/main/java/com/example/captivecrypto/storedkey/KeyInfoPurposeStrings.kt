// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties

val KeyInfo.purposeStrings:List<String>
    get() = KeyPurpose.purposeStrings(this)

private enum class KeyPurpose(val mask:Int) {
    Encrypt(KeyProperties.PURPOSE_ENCRYPT),
    Decrypt(KeyProperties.PURPOSE_DECRYPT),
    Sign(KeyProperties.PURPOSE_SIGN),
    Verify(KeyProperties.PURPOSE_VERIFY);

    // Next purpose requires API 28
    // wrap(KeyProperties.PURPOSE_WRAP_KEY)

    companion object {
        // Utility function to take the `purposes` property bit map and turn
        // it into a list of strings.
        fun purposeStrings(keyInfo: KeyInfo):List<String> {
            var mask:Int = 0
            val returning = mutableListOf<String>()
            values().forEach {
                if (keyInfo.purposes and it.mask != 0) {
                    mask = mask or it.mask
                    returning.add(it.name)
                }
            }

            // Check if there's anything in the purposes map that isn't in
            // the purposesList. If there is, add an explanatory message to
            // the purposes strings.
            if (keyInfo.purposes != mask) {
                returning.add(listOf(
                    "Unmatched info:",
                    keyInfo.purposes.toString(2).padStart(8, '0')
                    , " returning:",
                    mask.toString(2).padStart(8, '0')
                ).joinToString(""))
            }

            return returning
        }

    }
}
