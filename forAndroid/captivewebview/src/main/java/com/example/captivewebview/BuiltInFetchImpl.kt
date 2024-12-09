// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.net.HttpURLConnection
import java.net.URL
import javax.net.ssl.HttpsURLConnection

// FetchKey is for keys used by this file and FetchException.
enum class FetchKey {
    parameters,

    resource, options, method, body, bodyObject, headers
    , status, statusText, text, json, ok
    , peerCertificate, DER, length,

    keys, type, value, httpReturn
}

fun builtInFetchImpl(
    jsonObject: JSONObject, cause: ((throwable: Throwable) -> Unit)?
): JSONObject
{
    val (url, options) = try { parseFetchParameters(jsonObject) }
    catch (exception: FetchException) {
        exception.cause?.let { cause?.invoke(it) }
        return exception.toJSON(0) }

    val connection = try { prepareConnection(url, options) }
    catch (exception: FetchException) {
        exception.cause?.let { cause?.invoke(it) }
        return exception.toJSON(1) }

    val (fetchedRaw, details) = try {
        requestForFetch(connection, options)
    }
    catch (exception: FetchException) {
        exception.cause?.let { cause?.invoke(it) }
        return exception.toJSON(2)
    }
    finally {
        connection.disconnect()
    }

    // -   If the HTTP request was OK but the JSON parsing failed,
    //     return the JSON exception.
    // -   If the HTTP request wasn't OK but the JSON parsing succeeded,
    //     the parsed object will be included in the details.
    details.put(FetchKey.text, fetchedRaw)
    val jsonException: FetchException? = try {
        details.put(FetchKey.json, parseJSON(fetchedRaw))
        null
    }
    catch (exception: FetchException) {
        exception.cause?.let { cause?.invoke(it) }
        details.put(FetchKey.json, JSONObject.NULL)
        exception
    }

    return if (details.getBoolean(FetchKey.ok.name))
        jsonException?.run {
            // If JSON parsing failed, boost some details properties to
            // the top of the return object.
            val peerCertificate = details.remove(FetchKey.peerCertificate)
            val text = details.remove(FetchKey.text)
            details.remove(FetchKey.json)
            put(FetchKey.httpReturn to details)
                .toJSON(3)
                .put(FetchKey.text, text ?: JSONObject.NULL)
                .put(
                    FetchKey.peerCertificate,
                    peerCertificate ?: JSONObject.NULL)
        } ?: details
    else details
}

private fun parseFetchParameters(jsonObject: JSONObject)
        : Pair<URL, JSONObject>
{
    val parameters = jsonObject.opt(FetchKey.parameters) as? JSONObject
        ?: throw FetchException(
            "Fetch command had no `parameters` key, or its value"
                    + " isn't type JSONObject."
        ).put(
            FetchKey.keys to (jsonObject.names() ?: JSONArray()),
            FetchKey.type to jsonObject.opt(
                FetchKey.parameters)?.let {
                it::class.java.simpleName }
        )

    val resource = parameters.opt(FetchKey.resource) as? String
        ?: throw FetchException(
            "Fetch command parameters had no `resource` key, or its"
                    + " value isn't type String."
        ).put(
            FetchKey.keys to (parameters.names() ?: JSONArray()),
            FetchKey.type to parameters.opt(
                FetchKey.resource)?.let {
                it::class.java.simpleName }
        )

    return try { Pair(
        URL(resource),
        parameters.opt(FetchKey.options) as? JSONObject ?: JSONObject()
    ) }
    catch (exception: Exception) { throw FetchException(
        exception
    )
        .put(FetchKey.resource to resource) }
}

private fun prepareConnection(url: URL, options: JSONObject) = try {
    (url.openConnection() as HttpsURLConnection).apply {
        // ToDo: Check for known options with wrong type.
        (options.opt(FetchKey.method) as? String)?.let { requestMethod = it }
        (options.opt(FetchKey.body) as? String)?.let {
            // Assume JSON but already as a String somehow.
            setRequestProperty("Content-Type", "application/json")
            doOutput = true
        }
        (options.opt(FetchKey.bodyObject) as? JSONObject)?.let {
            setRequestProperty("Content-Type", "application/json")
            doOutput = true
        }
        (options.opt(FetchKey.headers) as? JSONObject)?.apply {
            keys().forEach {
                setRequestProperty(it, get(it) as String) } }
        connect()
    } }
catch (exception: Exception) { throw FetchException(
    exception
)
    .put(FetchKey.resource to url.toString()) }

private fun requestForFetch(
    connection: HttpsURLConnection, options: JSONObject
): Pair<String, JSONObject>
{
    val httpReturn = connection.serverCertificates[0].encoded.let {
        JSONObject().put(
            FetchKey.peerCertificate, JSONObject()
                .put(
                    FetchKey.DER,
                    Base64.encode(it, Base64.NO_WRAP).decodeToString()
                )
                .put(FetchKey.length, it.size)
        )
    }

    try {
        // ToDo: Check for known options with wrong type.
        val body =
            (options.opt(FetchKey.body) as? String)?.let {
                it + "\r\n\r\n"
            } ?: (options.opt(FetchKey.bodyObject) as? JSONObject)?.let {
                it.toString() + "\r\n\r\n"
            }

        body?.let {
            connection.outputStream.write(it.encodeToByteArray())
        }

        httpReturn.put(FetchKey.ok, connection.responseCode in 200..299)
            .put(FetchKey.status, connection.responseCode)
            .put(FetchKey.statusText, connection.responseMessage)
            .put(FetchKey.headers, headers(connection))

        // ToDo add a maximum size parameter to prevent buffer overrun.

        // Reading from the inputStream throws in the 404 case,
        // for example.
        val stream = if (connection.responseCode in 200..299)
            connection.inputStream else connection.errorStream

        return Pair(
            generateSequence {
                stream.read().takeUnless { it == -1 }?.toByte()
            }.toList().run {
                ByteArray(size) { index -> get(index) }
            }.decodeToString(), httpReturn
        )
    }
    catch (exception: Exception) {
        throw FetchException(exception).put(
            FetchKey.httpReturn to httpReturn
        )
    }
}

private fun headers(connection: HttpURLConnection):JSONObject {
    val headers = JSONObject()
    // Generate a sequence of Pair(Int, String) in which
    // -   If Int is zero, String is empty.
    // -   Otherwise String is the header field key with index Int - 1.
    generateSequence(Pair(0, "")) { it.first.let { index ->
        connection.getHeaderFieldKey(index)?.run { Pair(index+1, this) }
    } }.forEach { if (it.first > 0) it.second.let { key ->
        headers.put(key, connection.getHeaderField(key))
    } }
    return headers
}

private fun parseJSON(raw:String):Any = JSONTokener(raw).run {
    try { nextValue() }
    catch (exception: Exception) {
        throw FetchException(exception)
    }.also {
        if (it !is JSONObject && it !is JSONArray) throw FetchException(
            syntaxError(
                "Expected JSONObject or JSONArray but found"
                        + " ${it::class.java.simpleName}"
            )
        ).put(
            FetchKey.type to it::class.java.simpleName,
            FetchKey.value to it )
    } }
