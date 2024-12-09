// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

private enum KEY: String {
    typealias RawValue = String
    
    // Common keys.
    case parameters
    
    // Keys used by `load` command.
    case page, loaded
}

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary. TOTH for the setter:
// https://www.avanderlee.com/swift/custom-subscripts/#making-a-read-and-write-subscript
extension Dictionary where Key == String {
    fileprivate subscript(_ key:KEY) -> Value? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
    
    @discardableResult fileprivate mutating func removeValue(
        forKey key: KEY
    ) -> Value?
    {
        return removeValue(forKey: key.rawValue)
    }
}

public extension CaptiveWebView.BuiltInCommand {
    
    static func builtInLoad(
        _ viewController: WebViewController,
        _ viewControllerMap: Dictionary<String, WebViewController.Type>,
        _ commandDictionary: Dictionary<String, Any>
    ) throws -> Dictionary<String, Any>
    {
        let parameters = commandDictionary[.parameters]
        as? Dictionary<String, Any> ?? [:]
        
        guard let page = parameters[.page] as? String else {
            throw CaptiveWebViewError("No page specified.")
        }
        
        // The Captive Web View for Android has a map of page to Activity
        // subclass. That's because Kotlin introspection would require an
        // extra library in the application. The iOS runtime provides a form
        // of introspection built-in, so there's no need for a map here ...
        // except there is. The following looks promising but doesn't work.
        //
        // guard let controllerClass =
        //     Bundle.main.classNamed(page + "ViewController")
        //         as? UIViewController.Type
        //     else {
        //         throw ErrorMessage.message("No ViewController for \"\(page)\".")
        // }
        
        guard let controllerClass = viewControllerMap[page] else {
            throw CaptiveWebViewError(
                "Page \"\(page)\" isn't in viewControllerMap")
        }
        let loadedController = controllerClass.init()
#if os(macOS)
        // This code hasn't been tried, sorry.
        viewController.present(
            loadedController,
            asPopoverRelativeTo: viewController.view.bounds,
            of: viewController.view,
            preferredEdge: .maxX, behavior: .semitransient
        )
#else
        // TOTH: https://zonneveld.dev/ios-13-viewcontroller-presentation-style-modalpresentationstyle/
        loadedController.modalPresentationStyle = .fullScreen
        
        loadedController.modalTransitionStyle = .coverVertical

        // During the vertical cover animation, the web view hasn't been
        // loaded and so is a blank rectangle of the system background
        // colour. The contents of the current view disappear but there's no
        // sense of them being covered from bottom to top. The following
        // code addresses this by adding a thin border, and removing the
        // border after presentation.
        // The flipHorizontal transition doesn't seem to have this problme,
        // but it's old-fashioned looking.
        loadedController.view.layer.borderWidth = 1.0
        loadedController.view.layer.borderColor = UIColor.label.cgColor
        viewController.present(loadedController, animated: true) {
            loadedController.view.layer.borderWidth = 0
        }
#endif
        return [KEY.loaded.rawValue: page]
    }
    
}
