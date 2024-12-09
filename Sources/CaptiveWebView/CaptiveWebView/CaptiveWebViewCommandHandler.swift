// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import os.log

// A protocol can't be nested in a struct.

public protocol CaptiveWebViewCommandHandler {
    func handleCommand(_ command:Dictionary<String, Any>)
        -> Dictionary<String, Any?>
    func logCaptiveWebViewCommandHandler(_ message:String)
}

extension CaptiveWebViewCommandHandler {
    public func logCaptiveWebViewCommandHandler(_ message:String) {
        if #available(macOS 10.12, *) {
            os_log("%@", message)
        } else {
            NSLog("%@", message)
        }
    }
}
