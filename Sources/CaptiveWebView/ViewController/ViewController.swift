// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import WebKit
import os.log

extension CaptiveWebView.ViewController {
    
    internal static let nameSuffix = "ViewController"
    
    // It seems that the first time a WKWebView is loaded, it will appear
    // as a white rectangle. The appearance can be very brief, like a white
    // flash. That's a problem in dark mode because the appearance before
    // and after will be of a black screen. The fix is to hide the web view
    // for half a second.
    // The hiding takes place in the loadView, above, for example. The showing
    // is scheduled from here, in the navigation didCommit callback. That's
    // actually the only reason this ViewController subclass is also a
    // WKNavigationDelegate.
    public func webView(
        _ webView: WKWebView, didCommit navigation: WKNavigation!
    ) {
        webView.isHidden = true
        if let interval = loadVisibilityTimeOutSeconds {
            Timer.scheduledTimer(withTimeInterval: interval, repeats: false) {
                (timer:Timer) in webView.isHidden = false
            }
        }
        else {
            webView.isHidden = false
        }
    }
    
    public func loadCustom(scheme:String = CaptiveWebView.scheme,
                           file:String = "index.html") -> URL
    {
        return CaptiveWebView.load(in: webView, scheme:scheme, file:file)
    }
    
    public func loadMainHTML() -> URL {
        // Next line has a reference to the mainHTML property, which is declared
        // in the CaptiveWebView.swift file, in the class placeholder. It can't
        // be declared here in the extension.
        return self.loadCustom(file: mainHTML)
    }
    
    static func mainHTML(from viewController:WebViewController) -> String {
        var subClass = String(describing:type(of: viewController))
        if subClass.hasSuffix(CaptiveWebView.ViewController.nameSuffix) {
            subClass.removeLast(
                CaptiveWebView.ViewController.nameSuffix.count)
        }
        subClass.append(".html")
        return subClass
    }
    
    public func sendObject(
        _ command:Dictionary<String, Any>,
        _ completionHandler:((Any?, Error?) -> Void)? = nil)
    {
        CaptiveWebView.sendObject(to: webView, command, completionHandler)
    }
}
