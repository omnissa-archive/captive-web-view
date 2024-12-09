// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import WebKit

private enum Key:String { case messageBridge }

extension CaptiveWebView {

    @available(OSX 10.13, *)
    public static func makeWebView(frame:CGRect,
                            commandHandler:CaptiveWebViewCommandHandler?
        ) -> WKWebView
    {
        
        /*
         To add other URL schemes, register handlers here with code like the
         following:
         
         webView.configuration.setURLSchemeHandler(self, forURLScheme: "mailto")
         webView.configuration.setURLSchemeHandler(self, forURLScheme: "hucaj")
         
         Registration has to be here and not in the subclass because changes to
         the WKWebViewConfiguration made after the WKWebView has been
         instantiated are ignored.
         */
        return WKWebView(
            frame: frame,
            configuration: CaptiveWebView.makeWebViewConfiguration(
                commandHandler: commandHandler)
        )
    }
    
    @available(OSX 10.13, *)
    public static func makeWebViewConfiguration(
        commandHandler:CaptiveWebViewCommandHandler?
    ) -> WKWebViewConfiguration
    {
        let handler = CaptiveURLHandler()
        
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(handler, forURLScheme: scheme)
        configuration.userContentController.add(
            handler, name: Key.messageBridge.rawValue)
        handler.bridge = commandHandler
        return configuration
    }
    
    public static func setCommandHandler(
        of webView:WKWebView,
        to commandHandler:CaptiveWebViewCommandHandler?
    ) {
        if let handler = webView.configuration.urlSchemeHandler(
            forURLScheme: scheme
        ) as? CaptiveURLHandler {
            handler.bridge = commandHandler
        }
    }
    
    public static func load(in webView:WKWebView,
                            scheme loadScheme:String = scheme,
                            file:String = "index.html") -> URL
    {
        var builder = URLComponents()
        builder.scheme = loadScheme

        // We have to get a slash from somewhere. Could just put in a "/" but
        // that seems unsafe. Instead, rely on the first component of the path
        // always being slash.

        if
            let fileURL = CaptiveWebView.WebResource.findFile(
                under: Bundle.main.resourceURL ?? Bundle.main.bundleURL,
                tailComponents: [file]),
            let leadingSlash = fileURL.pathComponents.first
        {
            builder.path = leadingSlash + fileURL.relativePath
        }
        else {
            // This can be expected to fail later, in an orderly fashion, and
            // gets us out of having to throw here.
            builder.path = file
        }

        webView.load(URLRequest(url:builder.url!))
        return builder.url!
    }

    public static func sendObject(
        to webView:WKWebView,
        _ command:Dictionary<String, Any>,
        _ completionHandler:((Any?, Error?) -> Void)? = nil)
    {
        do {
            let jsonData:Data = try JSONSerialization.data(
                withJSONObject:command)
            // The UTF-8 encoding can fail and return nil. Throwing errors is
            // too hard to code in Swift so a JavaScript syntax error with a
            // telltale is introduced instead.
            let jsonString:String =
                String(data:jsonData, encoding:String.Encoding.utf8)
                    ?? "Couldn't encode \(#file) \(#line)"
            webView.evaluateJavaScript(
                "commandBridge.receiveObject(\(jsonString))",
                completionHandler: completionHandler
            )
        }
        catch {
            completionHandler?(nil, error)
        }
    }
}
