// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import CaptiveWebView

class MainViewController: CaptiveWebView.DefaultViewController {

    // Implicit raw values, see:
    // https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html#ID535
    private enum Command: String {
        case ready
    }
    
    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any?>
    {
        switch Command(rawValue: command) {
        case .ready:
            return [:]
        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }

}

