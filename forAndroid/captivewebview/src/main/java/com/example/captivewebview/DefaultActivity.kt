// Copyright 2019 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.annotation.SuppressLint

// This class is intended to be used as a base class only, so no need to warn
// about it not being registered in the manifest.
@SuppressLint("Registered")
open class DefaultActivity:
    com.example.captivewebview.Activity(),
    DefaultActivityMixIn
{
    // There's almost no code! This class is only here to pick up the
    // DefaultActivityMixIn code and apply it to the Local Web View Activity
    // base class.

    val activityMap = DefaultActivityMixIn.activityMap
    fun addToActivityMap(key:String, activityClassJava: Any) {
        DefaultActivityMixIn.addToActivityMap(key, activityClassJava)
    }
    fun addToActivityMap(map: Map<String, Any>) {
        DefaultActivityMixIn.addToActivityMap(map)
    }
    fun addToActivityMap(vararg pairs: Pair<String, Any>) {
        DefaultActivityMixIn.addToActivityMap(*pairs)
    }
}