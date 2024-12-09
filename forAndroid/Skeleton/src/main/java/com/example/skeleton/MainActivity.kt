// Copyright 2019 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.skeleton

import org.json.JSONObject
import java.lang.Exception

class MainActivity: com.example.captivewebview.DefaultActivity() {

    override fun commandResponse(
        command: String?,
        jsonObject: JSONObject
    ): JSONObject {
        return when(command) {
            "ready" -> jsonObject
            else -> super.commandResponse(command, jsonObject)
        }
    }

}