// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import CaptiveWebView

import os.log

class MainViewController: CaptiveWebView.DefaultViewController {
    
    var sent = false
    
    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any?>
    {
        // First time a command is received, send a dummy object to the
        // JavaScript layer, just for demonstration purposes.
        if !sent {
            _ = timedSend(seconds: 1)
            sent = true
        }
        switch command {
        case "ready":
            return [:]
        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }
    
    private func timedSend(seconds:TimeInterval) -> Timer {
        return Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) {
            (timer:Timer) in
            self.sendObject(["fireDate":"\(timer.fireDate)"]) {
                (result:Any?, error:Error?) in
                os_log("sendObject result: %@, error: %@",
                       String(describing: result), String(describing: error)
                )
            }
        }
    }
}
