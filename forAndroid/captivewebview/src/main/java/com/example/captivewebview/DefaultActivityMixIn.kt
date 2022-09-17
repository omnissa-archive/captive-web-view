// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Context
import android.content.Intent
import android.util.Base64
import com.example.captivewebview.ActivityMixIn.Companion.WEB_VIEW_ID
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.io.File
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class CauseIterator(private var throwable: Throwable?): Iterator<Throwable> {
    override fun hasNext(): Boolean {
        return throwable != null
    }

    override fun next(): Throwable {
        return throwable!!.also { throwable = throwable?.cause }
    }
}

/**
 * This MixIn can be used in an application whose Activity subclasses cannot be
 * based on the DefaultActivity class for some reason. Usage is like this.
 *
 *     class MainActivity :
 *         WhateverBaseActivity(), // Or just vanilla Activity()
 *         com.example.captivewebview.DefaultActivityMixIn
 *     {
 *         override fun onCreate(savedInstanceState: Bundle?) {
 *             super.onCreate(savedInstanceState)
 *             onCreateMixIn()
 *         }
 *         override fun onResume() {
 *             super.onResume()
 *             onResumeMixIn()
 *         }
 *     }
 */
interface DefaultActivityMixIn : ActivityMixIn, WebViewBridge {
    companion object {
        // Android Studio warns that these should start with capital letters but
        // they shouldn't because they have to match what gets sent from the JS
        // layer.
        private enum class Command {
            close, focus, load, write, UNKNOWN;

            companion object {
                fun matching(string: String?): Command? {
                    return if (string == null) null
                    else try { valueOf(string) }
                    catch (exception: Exception) { UNKNOWN }
                }
            }
        }

        private enum class KEY {
            // Common keys.
            command, confirm, failed, load, parameters,

            // Keys used by the `fetch` command.
            resource, options, method, bodyObject, headers
            , fetched, fetchError,

            // Keys used by the `write` command.
            base64decode, text, filename, wrote
        }
        private fun JSONObject.opt(key: KEY): Any? {
            return this.opt(key.name)
        }
        private fun JSONObject.put(key: KEY, value: Any?): JSONObject {
            return this.put(key.name, value)
        }
        // Enables members of the KEY enumeration to be used as keys in mappings
        // from String to any, for example as mapOf() parameters.
        private infix fun <VALUE> KEY.to(that: VALUE): Pair<String, VALUE> {
            return this.name to that
        }

        val activityMap = mutableMapOf<String, Class<android.app.Activity>>()

        fun addToActivityMap(key:String, activityClassJava: Any) {
            activityMap[key] = activityClassJava as? Class<android.app.Activity>
                ?: throw Exception(
                    "activityClassJava $activityClassJava cannot be cast to"
                    + " Class<android.app.Activity>"
                )
        }
        fun addToActivityMap(map: Map<String, Any>) {
            map.forEach { addToActivityMap(it.key, it.value) }
        }
        fun addToActivityMap(vararg pairs: Pair<String, Any>) {
            pairs.forEach { addToActivityMap(it.first, it.second) }
        }

        fun onCreateMixIn(
            activity: android.app.Activity, loadVisibilityTimeOutSeconds:Float?
        ) {
            ActivityMixIn.onCreateMixIn(activity, loadVisibilityTimeOutSeconds)
            val webView = activity
                .findViewById<com.example.captivewebview.WebView>(WEB_VIEW_ID)
            webView.webViewBridge = activity as WebViewBridge
        }

        fun builtInFetch(jsonObject: JSONObject): JSONObject {
            val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                ?: throw Exception("No parameters in fetch command")
            val resource:String = parameters.opt(KEY.resource) as? String
                ?: throw Exception("Parameter for resource isn't String")
            // ToDo check URL conversion.
            val url = URL(resource)

            val connection = url.openConnection() as HttpsURLConnection

            var requestBody:String? = null
            (parameters.opt(KEY.options) as? JSONObject)?.run {
                (opt(KEY.method) as? String)?.let {
                    connection.requestMethod = it
                }
                (opt(KEY.bodyObject) as? JSONObject)?.let {
                    connection.setRequestProperty(
                        "Content-Type", "application/json")
                    requestBody = it.toString() + "\r\n\r\n"
                }
                (opt(KEY.headers) as? JSONObject)?.let {
                    for (key in it.keys()) {
                        connection.setRequestProperty(key, it.get(key) as String)
                    }
                }
            }

            var fetchedData: ByteArray? = null
            var fetchError: Exception? = null
            try {
                requestBody?.let {
                    connection.doOutput = true
                    connection.outputStream.write(it.encodeToByteArray())
                }

                // ToDo add a maximum size parameter to prevent buffer overrun.
                val inputStream = connection.inputStream

                // ToDo
                // https://developer.android.com/reference/javax/net/ssl/HttpsURLConnection#getServerCertificates()

                val bytes = mutableListOf<Byte>()
                var byte = inputStream.read()
                while (byte != -1) {
                    bytes.add(byte.toByte())
                    byte = inputStream.read()
                }
                fetchedData = ByteArray(bytes.size) {index -> bytes[index]}
            }
            catch (exception:Exception) {
                fetchError = exception
            }
            finally {
                connection.disconnect()
            }

            return JSONObject().apply {
                fetchedData?.let { put(
                    // TOTH https://stackoverflow.com/a/57326083/7657675

                    KEY.fetched.name,
                    JSONTokener(it.decodeToString()).nextValue()
                ) }
                fetchError?.let { put(KEY.fetchError, fetchError.toString()) }
            }
        }

        fun builtInWrite(context: Context, jsonObject: JSONObject): JSONObject {
            val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                ?: throw Exception("No parameters in write command")
            val asciiToBinary = parameters.opt(KEY.base64decode) as? Boolean
                ?: false
            val text = parameters.opt(KEY.text) as? String
                ?: throw Exception("No text parameter in write command")
            val file = File(
                context.filesDir,
                parameters.opt(KEY.filename) as? String
                    ?: throw Exception(
                        "No file name parameter in write command")
            ).absoluteFile
            if (asciiToBinary) {
                file.writeBytes(Base64.decode(text, Base64.DEFAULT))
            }
            else {
                file.writeText(text)
            }
            return JSONObject(mapOf(KEY.wrote to file.toString()))
        }
    }

    // The following seems like the right way to do this:
    //
    //     fun <T> T.onCreateMixIn()
    //             where T:android.app.Activity, T:WebViewBridge
    //     {
    //         Companion.onCreateMixIn(this)
    //     }
    //
    // It doesn't get through the compiler maybe because it's a selective
    // override of the onCreateMixIn in the ActivityMixIn interface of which
    // this interface is a subclass.

    override fun android.app.Activity.onCreateMixIn() {
        // Call the onCreateMixIn in the Companion to this class.
        onCreateMixIn(this, loadVisibilityTimeOutSeconds)
    }

    // Note for later: The JS layer loads a new HTML page in the same Activity
    // by sending an object like this:
    //
    //     {"load": "page_to_load.html"}
    //
    // To load a new Activity, send a command like the following instead:
    //
    //     {"command": "load", "parameters": {"page": "PageSpecification"}}
    //
    // The PageSpecification string must be in the activityMap in the companion
    // object already.

    override fun handleCommand(jsonObject: JSONObject): JSONObject {
        // This method is a single return statement. Note that Kotlin try
        // returns a value, and the JSONObject put method returns the JSON
        // object instance.
        return try {
            // Next line uses opt() not optString(). That's because optString
            // returns "" if there's no mapping; opt() returns null which is
            // easier to detect.
            val returning = (jsonObject.opt(KEY.command) as? String)?.let {
                commandResponse(it, jsonObject)
            } ?: jsonObject

            returning.put(KEY.confirm,
                (jsonObject.opt(KEY.load) as? String)?.let {
                    // Next line declares that `this` must be an Activity.
                    this as Activity
                    val webView =
                        findViewById<com.example.captivewebview.WebView>(
                            WEB_VIEW_ID)
                    runOnUiThread {
                        webView.loadCustomAsset(applicationContext, it)
                    }
                    "UI thread \"$it\"."
                } ?:
                "${this.javaClass.simpleName} bridge OK."
            )
        } catch(exception: Exception) {
            val exceptions = JSONArray(CauseIterator(exception)
                .asSequence().map { it.toString() }.toList())
            jsonObject.put(KEY.failed,
                if (exceptions.length() == 1) exceptions[0] else exceptions)
        }
    }

    fun commandResponse(command: String?, jsonObject: JSONObject)
            : JSONObject
    {
        this as com.example.captivewebview.Activity
        return when (Command.matching(command)) {

            Command.close -> jsonObject.put("closed", true).also {
                this.finish()
            }

            Command.focus -> jsonObject.put("focussed", focusWebView())

            Command.load -> (jsonObject.opt(KEY.parameters) as JSONObject).let {
                // Scope function `let` returns the result of the lambda and
                // makes the context object available as `it`.
                jsonObject.put("loaded", this.loadActivity(it))
            }

            Command.write -> builtInWrite(this as Context, jsonObject)

            null -> jsonObject

            Command.UNKNOWN -> throw Exception("Unknown command \"$command\".")

        }
    }

    private fun loadActivity(parameters: JSONObject): String {
        // parameters.remove("page") //Induce error: No page value.
        // parameters.put("page", "duff_page") // Induce error: No page.
        val page = parameters.opt("page") as? String
            ?: throw Exception("No page specified.")
        val activityClass = activityMap[page]
            ?: throw Exception("Page \"$page\" isn't in activityMap.")
        this as Activity
        val intent = Intent(this, activityClass)
        this.startActivity(intent)
        return page
    }

}
