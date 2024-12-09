// Copyright 2022 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject

class WebView : android.webkit.WebView {
    companion object {
        val TAG = WebView::class.java.simpleName
    }
    constructor(context: Context) : super(context) {
        this.defaultSettings(context)
    }
    constructor(
        context: Context, attrs: AttributeSet?
    ) : super(context, attrs)
    {
        this.defaultSettings(context)
    }

    constructor(
        context: Context, attrs: AttributeSet?, defStyleAttr: Int
    ) : super(context, attrs, defStyleAttr)
    {
        this.defaultSettings(context)
    }

    constructor(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int,
        defStyleRes: Int
    ) : super(context, attrs, defStyleAttr, defStyleRes)
    {
        this.defaultSettings(context)
    }

    var webViewBridge : WebViewBridge? = null
        set(value) {
            val wasNull = (field == null)
            field = value
            if (wasNull) {
                this.addJavascriptInterface(this.bridge, "commandBridge")
            }
        }

    fun sendObject(
        jsonObject: JSONObject,
        resultCallback: ((JSONObject) -> Unit)?
    )
    {
        (context as Activity).runOnUiThread {
            evaluateJavascript("commandBridge.receiveObject($jsonObject);") {
                resultCallback?.invoke(JSONObject(it))
            }
        }
    }
    fun sendObject(
        map: Map<String, Any>,
        resultCallback: (JSONObject) -> Unit
    ) {
        this.sendObject(JSONObject(map), resultCallback)
    }

    private val bridge = object : Any() {
        @JavascriptInterface
        fun sendString(command: String) : String {
            val jsonObject = JSONObject(command)
            return webViewBridge!!.handleCommand(jsonObject).toString()
        }
    }

    // Native getWebViewClient is API level 26, which is too high. Get around
    // that by implementing a property like a polyfill.
    private val _webViewClient by lazy {
        com.example.captivewebview.WebViewClient()
    }

    // The default value for mixed content mode seems to depend on the Android
    // version. For that reason, this interface has a property that is set in
    // defaultSettings(), which is in turn called from every constructor.
    val defaultMixedContentMode:Int by lazy { this._defaultMixedContentMode!! }
    private var _defaultMixedContentMode:Int? = null

    @SuppressLint("SetJavaScriptEnabled")
    private fun defaultSettings(context: Context?) {
        this.settings.javaScriptEnabled = true
        this.settings.offscreenPreRaster = true
        android.webkit.WebView.setWebContentsDebuggingEnabled(true)
        this.webViewClient = this._webViewClient

        this.settings.mediaPlaybackRequiresUserGesture = false
        this.webChromeClient = WebChromeClient(this)
        this._defaultMixedContentMode = this.settings.mixedContentMode

        activateDarkModeMediaQuery()
    }

    private fun activateDarkModeMediaQuery() {
        // Android WebView doesn't implement the standard media query for dark
        // mode detection by default. TOTH for how to implement:
        // https://stackoverflow.com/a/61643614/7657675
        //
        // The setForceDarkStrategy() and setForceDark() methods are deprecated
        // but appear necessary to get dark mode support on early Android
        // versions. According to the Android developer website, these methods
        // will be a no-op if targetSdk >= 33. Seems harmless to leave them here
        // in that case.
        if(
            WebViewFeature.isFeatureSupported(
                WebViewFeature.FORCE_DARK_STRATEGY)
        ) {
            WebSettingsCompat.setForceDarkStrategy(settings,
                WebSettingsCompat.DARK_STRATEGY_WEB_THEME_DARKENING_ONLY)
        }
        else {
            Log.w(TAG,
                "WebViewFeature.isFeatureSupported(FORCE_DARK_STRATEGY)) false."
            )
        }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
            val inDarkMode = (resources.configuration.uiMode
                    and Configuration.UI_MODE_NIGHT_MASK
                    ) == Configuration.UI_MODE_NIGHT_YES
            if (inDarkMode) {
                WebSettingsCompat.setForceDark(settings,
                    WebSettingsCompat.FORCE_DARK_ON)
            }
        }
        else {
            Log.w(TAG, "WebViewFeature.isFeatureSupported(FORCE_DARK) false.")
        }
    }

    var captive:Boolean
        get() {return this._webViewClient.captive }
        set(value) {
            if (!value) {
                // If the web view isn't captive, it might need to access the
                // Internet, so check the application has permission here.

                // Convenience variable for debugger.
                val context = this.context

                val canInternet: Boolean = context.run {
                    this.packageManager.checkPermission(
                        Manifest.permission.INTERNET, this.packageName
                    ) == PackageManager.PERMISSION_GRANTED
                }

                if (!canInternet) {
                    Log.w(TAG,
                        "Possible missing permission android.permission.INTERNET")
                }
            }
            this._webViewClient.captive = value
        }

    fun loadCustomAsset(context: Context,
                        scheme: String = WebViewClient.ASSET_SCHEME,
                        file: String = "index.html") : Uri
    {
        val filePaths = WebResource.findAsset(context, file)
        val builder = Uri.Builder()
        builder.scheme(scheme)
        builder.authority(WebViewClient.ASSET_AUTHORITY)

        // If at least one path was found, then use the first one. Otherwise,
        // use the file name on its own, which will fail later so that an error
        // will be shown in the web view.
        builder.path(if (filePaths.count() > 0) filePaths[0] else file)

        loadUrl(builder.toString())
        return builder.build()
    }

    fun loadCustomAsset(context: Context,
                        file: String = "index.html") : Uri
    {
        return loadCustomAsset(context, WebViewClient.ASSET_SCHEME, file)
    }

}

class WebViewClient : android.webkit.WebViewClient() {
    companion object {
        // Setting the scheme to https seems to make Android WebView do the
        // following.
        //
        // -   Include the authority in the Origin header of the request.
        // -   Recognise the response as having a secure origin, and therefore
        //     making available the window.crypto.subtle object.
        //
        // This code originally used a custom scheme, `local`. Combining that
        // with an authority, `localhost`, that should be recognised as secure
        // didn't seem to work. The request Origin header only included the
        // scheme, not the authority, which may have been why it didn't work.
        const val ASSET_SCHEME = "https"
        const val ASSET_AUTHORITY = "localhost"
        val TAG = WebViewClient::class.java.simpleName
    }

    var captive = true

    override fun shouldOverrideUrlLoading(
        view: android.webkit.WebView?,
        request: WebResourceRequest?
    ): Boolean
    {
        val shouldOverride = super.shouldOverrideUrlLoading(view, request)
        if (shouldOverride) {
            return shouldOverride
        }

        // This safe cast somehow makes the extensions applied to Activity by
        // ActivityMixIn accessible here.
        (view?.context as? ActivityMixIn)?.run {
            (view.context as? android.app.Activity)?.let {
                it.runOnUiThread { view.visibility = View.INVISIBLE }
                it.makeVisibleWhenLoaded()
            }
        }

        return shouldOverride
    }

    override fun shouldInterceptRequest(
        view: android.webkit.WebView?, request: WebResourceRequest?
    ): WebResourceResponse?
    {
        val url = request?.url
        // Next line is useful for diagnostic purposes, like if you want to see
        // the Origin header.
        // val headers = request?.requestHeaders
        val scheme = url?.scheme ?: ""
        val authority = url?.authority ?: ""

        return when {
            // Request for an app asset, service it.
            scheme.equals(ASSET_SCHEME, true)
                    && authority.equals(ASSET_AUTHORITY, true)
            -> com.example.captivewebview.WebResource.assetResponse(
                    request!!, view!!.context)

            // Request for something else. If this is supposed to be a captive
            // web view, block the request.
            captive
            -> com.example.captivewebview.WebResource.htmlErrorResponse(403, """
                Resource "$url" with scheme "$scheme" and authority "$authority"
                cannot be loaded. Only "$ASSET_SCHEME" and "$ASSET_AUTHORITY"
                can be loaded.
                """.trimIndent())

            // Request for something else and this web view is allowed to load
            // it, return null to hand back to the default request handler.
            else -> null
        }
    }
}

interface WebViewBridge {
    fun handleCommand(jsonObject: JSONObject) : JSONObject
}
