// Copyright 2020 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import CaptiveWebView

@UIApplicationMain
class AppDelegate: CaptiveWebView.ApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        self.launch(MainViewController.self)
        
        return true
    }

}
