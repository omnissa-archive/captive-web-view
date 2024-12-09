// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import UIKit

import CaptiveWebView

class SpinnerViewController: CaptiveWebView.DefaultViewController {

    var polls = 0;

    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any?>
    {
        switch command {
        case "getStatus":
            polls = (polls + 1) % 30
            return ["message":"Dummy status \(polls)."]
        case "ready":
            return ["showLog":false]
        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }

}
