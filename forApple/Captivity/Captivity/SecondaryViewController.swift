// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import UIKit

import CaptiveWebView

class SecondaryViewController: CaptiveWebView.DefaultViewController {

    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any?>
    {
        switch command {
        case "ready":
            return [:]
        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }

}
