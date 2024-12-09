// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import org.json.JSONObject
import java.net.SocketTimeoutException

// Android Kotlin has many Exception subclasses but they don't seem to
// have properties for details. So a custom Exception is used that has a
// JSONObject for storing properties.
// In case an error is encountered by one of the component functions of
// builtInFetch they can throw an instance of the custom Exception and
// add details to it. If the error is from an Exception thrown by
// something that the component function called, that exception gets set
// as the cause of the custom Exception.
//
// TOTH custom Exception: https://stackoverflow.com/a/68775013/7657675
class FetchException(
    message: String? = null, cause: Throwable? = null
) : Exception(message, cause) {
    private val details = JSONObject()

    constructor(cause: Throwable) : this(null, cause)

    enum class Key {
        message, bytesTransferred
    }

    init {
        details.putOpt(Key.message, cause?.localizedMessage)
            .putOpt(
                Key.bytesTransferred.name,
                (cause as? SocketTimeoutException)?.bytesTransferred
            )
    }

    fun put(vararg pairs: Pair<String, Any?>) =
        pairs.forEach {
            details.put(it.first, it.second ?: JSONObject.NULL)
        }.let { this }

    fun toJSON(status: Int?): JSONObject = JSONObject()
        .put(FetchKey.ok, false)
        .putOpt(FetchKey.status, status)
        .putOpt(
            FetchKey.statusText,
            message ?: cause?.let { it::class.java.simpleName }
        )
        .putOpt(FetchKey.headers, details)
        .put(FetchKey.text, JSONObject.NULL)
        .put(FetchKey.json, JSONObject.NULL)
        .put(FetchKey.peerCertificate, JSONObject.NULL)
}
