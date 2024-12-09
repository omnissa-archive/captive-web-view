// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

//#if os(macOS)
//import AppKit
//#else
//import UIKit
//#endif

private enum Command: String {
    case fetch, load, write
#if !os(macOS)
    case close, focus
#endif
    case EMPTY=""
}

private enum KEY: String {
    // Keys used by the EMPTY load command.
    case load, dispatched
    
    // Keys used by the `close` command.
    case closed
    
    // Key used by the `focus` command.
    case focussedController
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

// BuiltInCommand will have static functions only. It is shared by iOS and
// macOS but macOS has a couple fewer commands.

extension CaptiveWebView.BuiltInCommand {

    public static func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>,
        map viewControllerMap: Dictionary<String, WebViewController.Type>?,
        presentingFrom viewController:WebViewController?
    ) throws -> Dictionary<String, Any?>
    {
        switch Command(rawValue:command) {

#if !os(macOS)
        case .close:
            guard let controller = viewController else {
                throw CaptiveWebViewError(
                    "Command requires View Controller \(commandDictionary).",
                    " Controller:\(String(describing: viewController))."
                )
            }
            controller.dismiss(animated: true, completion: nil)
            return [.closed: true].withStringKeys()
        
        case .focus:
            guard let controller = viewController else {
                throw CaptiveWebViewError(
                    "Command requires View Controller \(commandDictionary).",
                    " Controller:\(String(describing: viewController))."
                )
            }
            return [
                .focussedController: controller.becomeFirstResponder()
            ].withStringKeys()
#endif

        case .EMPTY:
            if let page = commandDictionary[.load] as? String,
               let controller = viewController as? CaptiveWebView.ViewController
            {
                // This branch handles a command like this:
                //
                //     {"load": "pagetoload.html"}
                //
                // It loads a new page in the same view controller. That is
                // different to this:
                //
                //     {"command": "load", "parameters": {"page": "spec"}}
                //
                // That loads a new view controller.
                
                // The dispatch mightn't be necessary but it seems better than
                // loading the web view here, when it's in the middle of
                // receiving a response.
                DispatchQueue.main.async {
                    _ = controller.loadCustom(file:page)
                }
                //
                // The dispatched load will bin the web content, including the
                // JS that receives the confirmation. If it logs it, that log
                // will be cleared before it can be seen, if everything is OK.
                return [.dispatched: page].withStringKeys()
            }
            else {
                // Empty dictionary.
                return [:]
            }

        case .fetch:
            return try builtInFetch(commandDictionary) {nsError in
                // Placeholder for logging or taking some other action with the
                // cause of an exception. The exception itself will have been
                // rendered into JSON and returned to the JS layer.
                let thrown = nsError
            } as Dictionary<String, Any?>

        case .load:
            guard let controller = viewController,
                  let controllerMap = viewControllerMap else
            {
                throw CaptiveWebViewError(
                    "Command requires View Controller and",
                    " map \(commandDictionary).",
                    " Controller:\(String(describing: viewController)).",
                    " Map:\(String(describing: viewControllerMap))."
                )
            }
            return try builtInLoad(controller, controllerMap, commandDictionary)
            
        case .write:
            return try builtInWrite(commandDictionary)
            
        default:
            throw CaptiveWebViewError(
                "Unknown command \"\(command)\" in",
                " \(String(describing: commandDictionary))")
        }
    }

    // Underload with nil parameters.
    public static func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
    ) throws -> Dictionary<String, Any?> {
        return try response(
            to: command, in: commandDictionary, map: nil, presentingFrom: nil)
    }

}
