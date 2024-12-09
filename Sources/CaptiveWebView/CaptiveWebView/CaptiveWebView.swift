// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import WebKit

#if os(macOS)
import AppKit
public typealias WebViewController = NSViewController
#else
import UIKit
public typealias WebViewController = UIViewController
#endif

private enum Key:String { case local }

// This struct is really a namespace. TOTH:
// https://stackoverflow.com/questions/24002821/how-to-use-namespaces-in-swift#24293236
//
// Actual class code is in extensions in the other .swift files, where possible.
// Some examples of where it isn't possible are:
//
// -   Property declarations, which aren't allowed in extensions.
// -   Open methods.
// -   Protocol declarations.
public struct CaptiveWebView {

    public static let scheme = Key.local.rawValue

    public class WebResource {}
    public class BuiltInCommand {}
    
    open class ViewController:
        WebViewController, CaptiveWebViewCommandHandler, WKNavigationDelegate
    {
        public static var viewControllerMap =
            Dictionary<String, WebViewController.Type>()
        
        public var loadVisibilityTimeOutSeconds:TimeInterval? = 0.4
        // See notes in the ViewController.swift file, near the
        // WKNavigationDelegate didCommit callback for an explanation of this
        // property's uses.
        
        // Use a crafty lambda to instantiate the WKWebView and set its
        // navigation delegate. This has to be lazy so that `self` is available
        // in the property initialiser.
        public lazy var webView: WKWebView = {
            var wkWebView = CaptiveWebView.makeWebView(
                frame: .zero, commandHandler: nil)
            wkWebView.navigationDelegate = self
            return wkWebView
        }()
        
        open var mainHTML:String {return ViewController.mainHTML(from: self)}

        public var bridge:CaptiveWebViewCommandHandler? {
            get {
                (webView.configuration.urlSchemeHandler(forURLScheme: scheme)
                    as? CaptiveURLHandler)?.bridge
            }
            set {
                setCommandHandler(of: webView, to: newValue)
            }
        }

        // Open methods have to be here, not in the extension, so that they can
        // be overriden.
        // These base class methods call the static methods, which are in the
        // extension, in the DefaultViewController.swift file.
        
        open func handleCommand(_ command: Dictionary<String, Any>) ->
            Dictionary<String, Any?>
        {
            CaptiveWebView.ViewController.handleCommand(self, command)
        }

        // This method should be private to this class and any subclass.
        // Swift doesn't seem to have a syntax for that, so its public instead.
        // If it's declared private, it cannot be called from a subclass with
        // super. notation.
        open func response(
            to command: String,
            in commandDictionary: Dictionary<String, Any>
            ) throws -> Dictionary<String, Any?>
        {
            try CaptiveWebView.BuiltInCommand.response(
                to: command,
                in: commandDictionary,
                map: CaptiveWebView.ViewController.viewControllerMap,
                presentingFrom: self
            )
        }
    }
    
    open class DefaultViewController: CaptiveWebView.ViewController
    {
#if os(macOS)
        open override func viewDidLoad() {
            bridge = self
            super.viewDidLoad()
            if #available(macOS 13.3, *) {
                webView.isInspectable = true
            }
        }
#else
        override open func loadView() {
            bridge = self
            super.loadView()
        }
#endif
    }
    
#if !os(macOS)
    // The next class doesn't have an equivalent in the macOS library. It
    // facilitates programmatic creation of the whole app user interface, which
    // would be a much bigger job on macOS.
    
    open class ApplicationDelegate: UIResponder, UIApplicationDelegate {
        // Following declaration has to be here in the class.
        public var window: UIWindow?
    }
#endif

}
