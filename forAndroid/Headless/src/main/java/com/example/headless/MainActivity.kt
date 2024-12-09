// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.headless

import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.ScrollView
import android.widget.TextView
import com.example.captivewebview.WebViewBridge
import com.example.captivewebview.put
import org.json.JSONObject
import java.lang.Exception

class MainActivity : Activity(), WebViewBridge {
    companion object {
//        val WEB_VIEW_ID = View.generateViewId()
        val TAG = MainActivity.javaClass.simpleName

        private enum class KEY {
            // Common keys.
            failed
        }

    }

    private var token:String? = null
    private var numericParameter = 1

    val webView by lazy {
        com.example.captivewebview.WebView(this).also {
            it.webViewBridge = this
            it.captive = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
    }

    override fun onResume() {
        super.onResume()
        if (webView.url == null) {
            webView.loadCustomAsset(this.applicationContext, "Headless.html")
        }
    }

    override fun handleCommand(jsonObject: JSONObject): JSONObject {
        // Next line uses opt() not optString(). That's because optString
        // returns "" if there's no mapping; opt() returns null which is
        // easier to detect.

        return try {
            jsonObject.also {
                it.opt("token")?.also {
                    (it as? String)?.also { this.token = it }
                        ?: throw Exception("Token isn't String:$it.")
                }
                    ?: showResult(it)
            }
        } catch(exception: Exception) {
            findViewById<TextView>(R.id.labelResults).text = "$exception"
            Log.e(TAG, "$exception")
            // Following line returns the exception to the web view, but since
            // it's headless it goes nowhere.
            jsonObject.put(KEY.failed, "$exception")
        }
    }

    private fun showResult(jsonObject: JSONObject) {
        runOnUiThread {
            findViewById<TextView>(R.id.labelResults)
                .text = jsonObject.toString(4)
        }
    }

    fun buttonSWAPIClicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\nSWAPI"
        webView.settings.mixedContentMode =
            android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        webView.sendObject(mapOf(
            "api" to "star-wars",
            "path" to listOf("planets", "$numericParameter")
        ), this::showResult)
        numericParameter += 1
        return
    }

    fun buttonGoRestGETClicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\ngo-rest GET"
        webView.settings.mixedContentMode = webView.defaultMixedContentMode
        webView.sendObject(
            mapOf(
                "api" to "go-rest",
                "path" to listOf("users", "${numericParameter + 18}")
            ), this::showResult
        )
        numericParameter += 1
        return
    }

    fun buttonGoRest401Clicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\ngo-rest 401"
        webView.settings.mixedContentMode = webView.defaultMixedContentMode
        webView.sendObject(
            mapOf(
                "api" to "go-rest",
                "method" to "POST", "path" to listOf("users")
            ), this::showResult
        )
        return
    }

    fun buttonGoRestBasicClicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\ngo-rest basic"
        webView.settings.mixedContentMode = webView.defaultMixedContentMode
        webView.sendObject(
            mapOf(
                "api" to "go-rest",
                "method" to "POST", "path" to listOf("users"),
                "basic-auth" to "Bearer",
                "token" to (token ?: "No token")
            ), this::showResult
        )
        return
    }

    fun toggleWebView(view: View) {
        findViewById<ScrollView>(R.id.scrollWebView).let { scrollWebView ->
            val visible = scrollWebView.visibility == View.VISIBLE
            scrollWebView.visibility = if (visible) View.GONE else View.VISIBLE
            if (visible) {
                scrollWebView.removeView(webView)
            }
            else {
                scrollWebView.addView(webView)
            }
            findViewById<ScrollView>(R.id.scrollResults).visibility =
                if (visible) View.VISIBLE else View.GONE
        }
    }
}
