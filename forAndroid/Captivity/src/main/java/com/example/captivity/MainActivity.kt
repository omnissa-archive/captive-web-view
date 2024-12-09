// Copyright 2022 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivity

import android.os.Bundle
import org.json.JSONObject

class MainActivity: com.example.captivewebview.DefaultActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        addToActivityMap(
            "Secondary" to SecondaryActivity::class.java,
            "Spinner" to SpinnerActivity::class.java
        )
    }

    // Android Studio warns that `ready` should start with a capital letter but
    // it shouldn't because it has to match what gets sent from the JS layer.
    private enum class Command {
        ready, UNKNOWN;

        companion object {
            fun matching(string: String?): Command? {
                return if (string == null) null
                else try { valueOf(string) }
                catch (exception: Exception) { UNKNOWN }
            }
        }
    }

    override fun commandResponse(command: String?, jsonObject: JSONObject) =
        when(Command.matching(command)) {
            Command.ready -> jsonObject
            else -> super.commandResponse(command, jsonObject)
        }
}
