// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import WebKit
import os.log

import CaptiveWebView

class ViewController: UIViewController, CaptiveWebViewCommandHandler {
    var token:String? = nil
    
    func handleCommand(
        _ command: Dictionary<String, Any>) -> Dictionary<String, Any?>
    {
        guard let tokenAny:Any = command["token"] else {
            os_log("handleCommand(%@)", command)
            resultsLabel.text = String(describing: command)
            return command
        }
        guard let tokenString = tokenAny as? String else {
            var returning = command
            returning["failed"] =
                "Token isn't String: \(String(describing: tokenAny))"
            return returning
        }
        self.token = tokenString
        return command
    }
    
    func logCaptiveWebViewCommandHandler(_ message:String) {
        // Demonstrate the override.
        os_log("%@ %@", "Headless", message)
    }
    
    var wkWebView: WKWebView?
    var numericParameter = 1

    @IBOutlet weak var scrollResults: UIScrollView!
    @IBOutlet weak var resultsLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Next code instantiates a Captive WKWebView then hides it, then adds
        // it to the view hierarchy. If it isn't added to the hierarchy, the JS
        // running inside it doesn't work well. For example, any code in a
        // setTimeout doesn't execute ever. Also, Fetch promises don't resolve.
        let madeWebView = CaptiveWebView.makeWebView(
            frame:CGRect(x: 0, y: 0, width: 100, height: 100),
            commandHandler: self)
        madeWebView.isHidden = true
        self.view.addSubview(madeWebView as UIView)
        self.wkWebView = madeWebView

        _ = CaptiveWebView.load(in: wkWebView!,
                                scheme: CaptiveWebView.scheme,
                                file: "Headless.html")
        
        // Next line makes the web view the same size and position as the
        // scrolling results view. There's a button to toggle between the two.
        CaptiveWebView.constrain(view: madeWebView, to: scrollResults)
    }
    
    func sendObjectCallback(result:Any?, error:Error?) {
        os_log(
            "result: %@, error: %@",
            String(describing: result), String(describing: error))
    }

    @IBAction func swapiClicked(_ sender: Any) {
        resultsLabel.text = "Sending\nSWAPI"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"star-wars",
                "path":["planets", String(describing: numericParameter)]
            ], self.sendObjectCallback)
        numericParameter += 1
    }
    
    @IBAction func goRestGETClicked(_ sender: Any) {
        resultsLabel.text = "Sending\ngo-rest GET"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"go-rest",
                "path":["users", String(describing: numericParameter + 18)],
            ], self.sendObjectCallback)
        numericParameter += 1
    }

    @IBAction func goRest401Clicked(_ sender: Any) {
        resultsLabel.text = "Sending\ngo-rest 401"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"go-rest",
                "method": "POST", "path":["users"]
            ], self.sendObjectCallback)
    }
    
    @IBAction func goRestBasicClicked(_ sender: Any) {
        resultsLabel.text = "Sending\ngo-rest basic"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"go-rest",
                "method": "POST", "path":["users"],
                "basic-auth":"Bearer",
                "token": self.token ?? "No token"
            ], self.sendObjectCallback)
    }
    
    @IBAction func toggleWebView(_ sender: Any) {
        wkWebView?.isHidden = scrollResults.isHidden
        scrollResults.isHidden = !scrollResults.isHidden
    }
}
