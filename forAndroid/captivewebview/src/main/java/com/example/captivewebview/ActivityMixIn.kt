// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Context
import android.content.pm.ActivityInfo
import android.os.Handler
import android.util.Log
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import org.json.JSONObject

interface ActivityMixIn {
    companion object {
        val WEB_VIEW_ID = View.generateViewId()
        val nameSuffix = "Activity"

        fun onCreateMixIn(
            activity: android.app.Activity, loadVisibilityTimeOutSeconds:Float?
        ) {
            warnMissingDeclaration(activity)
            val activityMixIn = activity as? ActivityMixIn

            com.example.captivewebview.WebView(activity).apply {
                id = WEB_VIEW_ID
                // Make the web view fill its parent.
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
                // Make the web view invisible now, if it will be made visible
                // later.
                activityMixIn?.also {
                    visibility = View.INVISIBLE
                }
                // Create a Frame Layout, add the web view to it, and make it
                // the content view of the Activity.
                FrameLayout(activity).run {
                    addView(this@apply)
                    activity.setContentView(this)
                }
                // Schedule making the web view visible, and load the main HTML.
                activityMixIn?.also {
                    loadCustomAsset(activity, it.mainHTML)
                    makeVisibleWhenLoaded(activity, loadVisibilityTimeOutSeconds)
                }
            }
        }

        private fun warnMissingDeclaration(activity: android.app.Activity) {
            // An Activity based on this Activity should declare that it handles
            // some configuration changes in the Android manifest. If it doesn't,
            // the default handling will apply, which means that the Activity gets
            // destroyed and re-created when, for example, the device orientation is
            // changed. This in turn means that the WebView instance will be
            // destroyed and any data in it lost.
            //
            // Note that it seems unnecessary to implement anything to handle the
            // changes. The WebView does that on its own. So there isn't an
            // onConfigurationChanged() implementation here.
            //
            // It'd be nice to make that happen in the manifest, i.e. declare that
            // handling in the library manifest for this class and have that merged
            // into any subclass by default. However, there doesn't seem to be a way
            // to do that. Second best is to check whether the required configuration
            // change handling is declared and print a warning if not.
            //
            // The dark-mode documentation says that an Activity could avoid
            // getting recreated during changes between light-mode and dark mode
            // by adding "|uiMode" to the android:configChanges attribute.
            // It doesn't seem to work. Whether that's there or not, the
            // onConfigurationChanged method doesn't get invoked. Maybe it
            // depends on theme?
            val configInfo = activity.packageManager.getActivityInfo(
                activity.componentName, 0
            ).configChanges
            val missing = mutableListOf<String>()
            if (configInfo and ActivityInfo.CONFIG_ORIENTATION == 0) {
                missing.add("orientation")
            }
            if (configInfo and ActivityInfo.CONFIG_SCREEN_SIZE == 0) {
                missing.add("screenSize")
            }
            if (configInfo and ActivityInfo.CONFIG_KEYBOARD_HIDDEN == 0) {
                missing.add("keyboardHidden")
            }
            if (missing.count() > 0) {
                // Following statement uses `activity` in the TAG parameter so
                // that the subclass name appears there.
                Log.w(
                    activity.javaClass.canonicalName,
                    "Missing declaration in manifest <activity>" +
                            " android:configChanges=" +
                            missing.joinToString(
                                prefix = "\"", separator = "|", postfix = "\"."
                            )
                )
            }
        }

        fun makeVisibleWhenLoaded(
            activity: android.app.Activity, timeOutSeconds:Float?
        ) {
            val view = activity.findViewById<View>(WEB_VIEW_ID)
            val milliseconds = timeOutSeconds?.times(1000F)?.toLong()
            if (milliseconds == null) {
                view.visibility = View.VISIBLE
            }
            else {
                Handler(activity.mainLooper).postDelayed(Runnable {
                    activity.runOnUiThread { view.visibility = View.VISIBLE }
                }, milliseconds)
            }
        }
    }

    fun android.app.Activity.onCreateMixIn() {
        onCreateMixIn(this, loadVisibilityTimeOutSeconds)
    }

    // It seems that the first time a web view is loaded, it will appear as a
    // white rectangle. The appearance can be very brief, like a white flash.
    // That's a problem in dark mode because the appearance before and after
    // will be of a black screen. The fix is to hide the web view for a short
    // time. The hiding takes place in the onCreateMixIn, and the
    // revealing is scheduled from there by calling makeVisibleWhenLoaded().
    val android.app.Activity.loadVisibilityTimeOutSeconds:Float?
        get() = 0.4F

    fun android.app.Activity.makeVisibleWhenLoaded() {
        Companion.makeVisibleWhenLoaded(this, loadVisibilityTimeOutSeconds)
    }

    val mainHTML: String
        get() {
            return this.javaClass.simpleName.removeSuffix(nameSuffix) + ".html"
        }

    fun android.app.Activity.focusWebView(): Boolean {
        // https://developer.android.com/training/keyboard-input/visibility#ShowOnDemand
        val view = findViewById<View>(WEB_VIEW_ID)
        val requested = view.requestFocus()
        if (requested) {
            val manager = getSystemService(
                Context.INPUT_METHOD_SERVICE
            ) as InputMethodManager
            manager.showSoftInput(view, InputMethodManager.SHOW_IMPLICIT)
        }
        return requested
    }

    fun android.app.Activity.sendObject(
        jsonObject: JSONObject,
        resultCallback: ((JSONObject) -> Unit)?
    ) {
        val webView =
            findViewById<com.example.captivewebview.WebView>(WEB_VIEW_ID)
        runOnUiThread {
            webView.sendObject(jsonObject, resultCallback)
        }
    }
    fun android.app.Activity.sendObject(
        map: Map<String, Any>,
        resultCallback: ((JSONObject) -> Unit)?
    ) {
        this.sendObject(JSONObject(map), resultCallback)
    }

}