// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import kotlinx.serialization.Serializable

@Serializable
data class KeysDeletion(
    val deleted:List<String>, val notDeleted:Map<String, String>
)

fun deleteAllStoredKeys(
    providerName: String = KEY.AndroidKeyStore.name
): KeysDeletion
{
    val keyStore = loadKeyStore(providerName)
    val deleted = mutableListOf<String>()
    val notDeleted = mutableMapOf<String, String>()
    // Next part could maybe be done like this:
    //
    //     keyStore.aliases().toList().forEach { ... }
    //
    // However, it seems hazardous to delete from the key store in scope
    // of an iterator across the key store. So there's a separate
    // variable instead.
    val deleting = keyStore.aliases().toList()
    deleting.forEach {
        try {
            keyStore.deleteEntry(it)
            deleted.add(it)
        }
        catch (exception: Exception) {
            notDeleted[it] = exception.toString()
        }
    }
    return KeysDeletion(deleted.toList(), notDeleted)
}
