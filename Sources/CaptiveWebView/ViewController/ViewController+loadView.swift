// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension CaptiveWebView.ViewController {
    
#if os(macOS)
    open override func viewDidLoad() {
        super.viewDidLoad()
        setColours()
        webView.isHidden = true
        self.view.addSubview(self.webView, positioned: .below, relativeTo: nil)
        CaptiveWebView.constrain(view:webView, to:view)
        
        // Uncomment the following to add a diagnostic border around the web
        // view.
        // self.webView.layer?.borderColor = NSColor.blue.cgColor
        // self.webView.layer?.borderWidth = 4.0
        // self.webView.layer?.backgroundColor = NSColor.yellow.cgColor
        
        _ = self.loadMainHTML()
    }
#else
    override open func loadView() {
        // Root view is a generic UIView. The OS will resize it to the size of
        // the screen.
        // Note that the web view isn't used as the root view. The web view can
        // then easily be constrained to the safe area. The root view fills the
        // whole screen; the web view will fill the safe area.
        view = UIView()
        
        setColours()
        
        // The web view will have been instantiated by the property initialiser.
        // It doesn't get inserted into the view hierarchy until now though.
        // Hide it before inserting it.
        webView.isHidden = true
        view.addSubview(webView)
        
        // Uncomment the following to add a diagnostic border around the web
        // view.
        // self.webView.layer.borderColor = UIColor.blue.cgColor
        // self.webView.layer.borderWidth = 4.0
        // self.webView.layer.backgroundColor = UIColor.yellow.cgColor
        // self.view.layer.backgroundColor = UIColor.cyan.cgColor
        
        // Load the web resources. This also causes invocation of the
        // WKNavigationDelegate didCommit callback, which is in the
        // CaptiveWebView.swift file.
        _ = self.loadMainHTML()
        
        // The web view will have been instantiated with a zero frame. Now that
        // it's in the view hierarchy, it can be constrained to the safe area.
        // Note that the constraint can't be applied before the web view is
        // inside the view hierarchy, and only constraints to other views in the
        // same hierarchy are allowed.
        CaptiveWebView.constrain(view: webView, to: view.safeAreaLayoutGuide)
    }
    
    open override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        // This callback is invoked when the device is changed between dark mode
        // and light mode. Resetting the colours to systemBackground will apply
        // the new mode.
        if previousTraitCollection?.userInterfaceStyle
            != traitCollection.userInterfaceStyle
        {
            setColours()
        }
    }
#endif
    
    private func setColours() {
#if os(macOS)
        // TOTH https://stackoverflow.com/a/60122916/7657675
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        webView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
#else
        view.layer.backgroundColor = UIColor.systemBackground.cgColor
        webView.layer.backgroundColor = UIColor.systemBackground.cgColor
#endif
    }
}
