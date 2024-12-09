// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import android.webkit.PermissionRequest

class WebChromeClient(private val webView: WebView):
    android.webkit.WebChromeClient()
{
    companion object {
        private val TAG = WebChromeClient::class.java.simpleName
    }

    // Code in WebView has requested a permission, like camera access.
    override fun onPermissionRequest(request: PermissionRequest) {
        val cameraRequested = handleCameraRequest(request)
        if ((!cameraRequested) || (request.resources.size != 1)) {
            Log.w(TAG, "Permissions other than camera requested." +
                    " List:${request.resources} Camera:$cameraRequested.")
        }
    }

    private fun handleCameraRequest(request: PermissionRequest):Boolean {
        // If camera access isn't being requested, return false.
        (!request.resources.contains(PermissionRequest.RESOURCE_VIDEO_CAPTURE))
                && return false

        // Convenience variable for the corresponding system permission.
        val wants = arrayOf(Manifest.permission.CAMERA)

        // Check if the corresponding system permission has been granted to
        // the app.
        val context = this.webView.context
        val hasAppPermission = context.packageManager.checkPermission(
            wants[0], context.packageName
        ) == PackageManager.PERMISSION_GRANTED

        if (hasAppPermission) {
            // App has permission, automatically grant to the WebView code. Only
            // the camera permission is granted, not every permission in the
            // request.
            request.grant(arrayOf((PermissionRequest.RESOURCE_VIDEO_CAPTURE)))
            return true
        }

        // App doesn't have permission. Deny the request now but initiate the
        // system permission request. The WebView code will have to request the
        // permission again. The system permission request is asynchronous and
        // has user interaction so it can't be inlined here.
        request.deny()

        // Assume the web page makes it obvious why camera permission is being
        // requested.
        //
        // In case the end user has previously denied the permission, calling
        // shouldShow... seems to reset an internal flag, and hence force
        // Android to request the permission again.
        (context as? Activity)?.apply {
            requestPermissions(
                wants,
                if (shouldShowRequestPermissionRationale(wants[0])) 0 else 1
            )
            Log.w(TAG, "Possible missing permission android.permission.CAMERA")
        } ?: Log.w(TAG, "Permissions requested from non-Activity: ${context}.")

        return true
    }
}
