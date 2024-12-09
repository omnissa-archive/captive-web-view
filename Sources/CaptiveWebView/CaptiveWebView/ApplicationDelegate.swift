// Copyright 2020 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

#if os(iOS)
import Foundation
import UIKit

extension CaptiveWebView.ApplicationDelegate {

    /**
     Launch a view controller as the user interface without using a storyboard.
     
     - Parameter ViewController: Class of the view controller. Use syntax like
     `ViewControllerClassName.self` in the calling code.
     - Parameter screen: UIScreen to fill with the view. By default, the main
     screen of the device.
     
     */
    // This function uses Swift Generics syntax with type constraints. See:
    // https://docs.swift.org/swift-book/LanguageGuide/Generics.html
    // By the way, UIViewController is a class, not an interface.
    //
    // The extension doesn't have to be declared as public, because the class is
    // public. However, the method here does have to be declared as public.
    public func launch<V:UIViewController>(_ ViewController:V.Type,
                                           screen:UIScreen = UIScreen.main)
    {
        // TOTH: https://stackoverflow.com/questions/24046898/how-do-i-create-a-new-swift-project-without-using-storyboards#25482567
        let uiWindow: UIWindow = UIWindow(frame: screen.bounds)
        
        // It seems that it isn't allowed to set the `window` property,
        // except as it's done here, by putting the code to set it in a
        // subclass.
        self.window = uiWindow
        
        // Instantiating from a parameter requires explicit init() call.
        uiWindow.rootViewController = ViewController.init()
        uiWindow.makeKeyAndVisible()
    }

}
#endif
