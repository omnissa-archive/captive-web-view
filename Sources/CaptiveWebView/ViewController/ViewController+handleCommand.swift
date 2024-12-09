// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

private enum KEY: String {
    // Common keys.
    case command, confirm, failed, secure
}

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary. TOTH for the setter:
// https://www.avanderlee.com/swift/custom-subscripts/#making-a-read-and-write-subscript
extension Dictionary where Key == String {
    fileprivate subscript(_ key:KEY) -> Value? {
        get {
            self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue
        }
    }
}

// Clunky but can be used to create a dictionary with String keys from a
// dictionary literal with KEY keys.
extension Dictionary where Key == KEY {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0.rawValue, $1)
        })
    }
}

extension CaptiveWebView.ViewController {
    static func handleCommand(
        _ viewController: CaptiveWebView.ViewController,
        _ command: Dictionary<String, Any>
        ) -> Dictionary<String, Any?>
    {
        var returning = command as [String:Any?]
        do {
            let commandAny:Any = command[.command] ?? ""
            guard let commandString = commandAny as? String else {
                throw CaptiveWebViewError(
                    "Command isn't String: " + String(describing: commandAny))
            }

            let responded = try viewController.response(to:commandString,
                                                        in:command)
            returning.merge(responded) {(_, new) in new}
            // Confirmation message starts with the class name of self.
            // TOTH: https://stackoverflow.com/a/34878224
            returning[.confirm] =
                String(describing: type(of: viewController)) + " bridge OK."
            returning[.secure] = viewController.webView.hasOnlySecureContent
        }
        catch let error as CaptiveWebViewError {
            returning[.failed] = error.localizedDescription
        }
        catch {
            returning[.failed] = error.localizedDescription
        }
        return returning
    }
}
