// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import WebKit

import os.log

@available(OSX 10.12, *)
class CaptiveURLHandler: NSObject, WKURLSchemeHandler, WKScriptMessageHandler {
    
    public var bridge: CaptiveWebViewCommandHandler?
    
    @available(OSX 10.13, *)
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let taskURL: URL = urlSchemeTask.request.url else {
            os_log("Null URL in task request \"%@\".",
                   urlSchemeTask.request.description)
            urlSchemeTask.didFailWithError(CaptiveWebViewError(
                "Null URL in task request \(urlSchemeTask.request)."))
            return
        }
        
        do {
            let responseData:Data
            let responseURL:URL
            if let (getData, getURL) = try self.do_GET(urlSchemeTask.request) {
                responseData = getData
                responseURL = getURL
            }
            else if let (postData, postURL) =
                try self.do_POST(urlSchemeTask.request)
            {
                responseData = postData
                responseURL = postURL
            }
            else {
                throw CaptiveWebViewError("Unknown request type " +
                    String(describing: urlSchemeTask.request.httpMethod))
            }
            let mimeType = try CaptiveWebView.WebResource.getMIMEType(
                responseURL)
            
            urlSchemeTask.didReceive(URLResponse(
                url: taskURL,
                mimeType: mimeType,
                expectedContentLength: responseData.count,
                textEncodingName: "utf8"))
            urlSchemeTask.didReceive(responseData)
            urlSchemeTask.didFinish()
        }
        catch {
            os_log("Resource failed \"%@\": %@",
                   taskURL.description, error.localizedDescription)
            urlSchemeTask.didFailWithError(error)
        }
    }
    
    func do_GET(_ request:URLRequest) throws ->
        (responseData:Data, responseURL:URL)?
    {
        guard request.httpMethod?.uppercased() == "GET" else {
            return nil
        }
        guard let requestURL: URL = request.url else {
            throw CaptiveWebViewError("Null URL in task request \(request).")
        }
        
        var baseURL:URL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let responseURL = baseURL.appending(pathComponents: requestURL)
        var resourceError: Error?
        
        // Try to get the resource from two locations:
        //
        // -   The main bundle of the application.
        // -   The bundle of the framework.
        //
        // If it isn't found in either, throw the error from the main bundle, at
        // the end of this method.
        
        do {
            let responseData = try Data(contentsOf: responseURL)
            bridge?.logCaptiveWebViewCommandHandler(
                "From app do_GET(\(request)) \"\(responseURL)\"")
            return (responseData, responseURL)
        }
        catch {
            // Keep the main bundle error, in case the framework bundle fails
            // too.
            resourceError = error
        }
        
        // To understand these, now unused, catch clauses, see the article:
        // Handling Cocoa Errors in Swift.
        // https://developer.apple.com/documentation/swift/cocoa_design_patterns/handling_cocoa_errors_in_swift
        //        catch CocoaError.fileReadNoSuchFile {
        //            resourceContent = nil
        //            resourceNSError = nil
        //            resourceNotFound = true
        //        }
        //        catch let nsError as NSError {
        //            resourceContent = nil
        //            resourceNSError = nsError
        //            resourceNotFound = false
        //        }
        //        ...
        //        if resourceNotFound {
        //            urlSchemeTask.didReceive(HTTPURLResponse(
        //                url: urlSchemeTask.request.url!,
        //                statusCode: 404, httpVersion: nil, headerFields: nil)!)
        //            urlSchemeTask.didFinish()
        //
        //            //            urlSchemeTask.didFailWithError(NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileNoSuchFile.rawValue))
        //            return
        //        }
        
        // Not found at the path. Check in the resources that come with the
        // library. This code will be invoked to retrieve the library JavaScript
        // like the captivewebview.js file.
        //
        // Bundle for self gets the bundle that includes this class, which
        // is the CaptiveWebView framework.
        let bundle = Bundle(for: type(of: self))
        baseURL = bundle.resourceURL ?? bundle.bundleURL
        
        // Handy diagnostic code for anybody interested.
        // os_log("main resource:%@\nself:%@\nbase:%@",
        //        Bundle.main.resourceURL?.description ?? "nil",
        //        bundle.bundleURL.description, baseURL.description)

        // When there was a "WebAssets" group with a directory, it
        // didn't seem to feature in the bundle.
        guard let libraryURL = CaptiveWebView.WebResource.findFile(
            under: baseURL,
            tailComponents: ["library", requestURL.lastPathComponent]) else
        {
            throw resourceError!
        }

        do {
            let responseData = try Data(contentsOf: libraryURL)
            bridge?.logCaptiveWebViewCommandHandler(
                "From library do_GET(\(request)) \"\(libraryURL)\"")
            return (responseData, libraryURL)
        }
        catch {
            throw resourceError!
        }
    }
    
    func do_POST(_ request:URLRequest) throws ->
        (responseData:Data, responseURL:URL)?
    {
        guard request.httpMethod?.uppercased() == "POST" else {
            return nil
        }
        
        guard let body = CaptiveWebView.WebResource.bodyFrom(request: request)
            else {
                throw CaptiveWebViewError("Body wasn't dictionary")
        }
        
        // If a bridge has been set, then return its return value, otherwise
        // return the input.
        // Add a pretend URL with the required extension to get the MIME type
        // for JSON.
        return try (
            JSONSerialization.data(
                withJSONObject: self.bridge?.handleCommand(body) ?? body),
            URL(fileURLWithPath: "body.json"))
    }
    
    @available(OSX 10.13, *)
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Invoked to tell you to stop. Requests to local: don't take long
        // enough to have to be cancelled.
        os_log("URL handler stop \"%@\"", urlSchemeTask.description)
    }
    
    // Following method would be called by the Message bridge subclass, which
    // is unused. See notes in the bridge.js and captivewebview.js files.
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage)
    {
        // If the JS passes an object, it comes out as a dictionary.
        let body = message.body as! Dictionary<String, Any>
        os_log("message \"%@\".", body.description)
    }
    
}
