// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import WebKit

extension CaptiveWebView {
#if os(macOS)
    
    // macOS version, takes two NSView parameters.
    public static func constrain(
        view left: NSView, to right: NSView, leftSide:Bool = false
    ) {
        left.translatesAutoresizingMaskIntoConstraints = false
        left.topAnchor.constraint(
            equalTo: right.topAnchor).isActive = true
        left.bottomAnchor.constraint(
            equalTo: right.bottomAnchor).isActive = true
        left.leftAnchor.constraint(
            equalTo: right.leftAnchor).isActive = true
        left.rightAnchor.constraint(
            equalTo: leftSide ? right.centerXAnchor : right.rightAnchor
        ).isActive = true
    }
    // TOTH:
    //    https://github.com/dasher-project/redash/blob/master/Keyboard/foriOS/DasherApp/Keyboard/KeyboardViewController.swift#L129
    
#else
    
    // iOS version, takes either of the following:
    //
    // -   Two UIView parameters.
    // -   One UIView and one UILayoutGuide.
    //
    // The UIView.safeAreaLayoutGuide property is a UILayoutGuide.
    public static func constrain(
        view left: UIView, to right: UIView, leftHalf:Bool = false
    ) {
        setAnchors(of: left,
                   top: right.topAnchor,
                   left: right.leftAnchor,
                   bottom: right.bottomAnchor,
                   right: leftHalf ? right.centerXAnchor : right.rightAnchor)
    }
    
    public static func constrain(
        view: UIView, to guide: UILayoutGuide, leftHalf:Bool = false
    ) {
        setAnchors(of: view,
                   top: guide.topAnchor,
                   left: guide.leftAnchor,
                   bottom: guide.bottomAnchor,
                   right: leftHalf ? guide.centerXAnchor : guide.rightAnchor)
    }
    
    public static func setAnchors(
        of view: UIView,
        top: NSLayoutYAxisAnchor,
        left:NSLayoutXAxisAnchor,
        bottom: NSLayoutYAxisAnchor,
        right: NSLayoutXAxisAnchor
    ) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: top).isActive = true
        view.leftAnchor.constraint(equalTo: left).isActive = true
        view.bottomAnchor.constraint(equalTo: bottom).isActive = true
        view.rightAnchor.constraint(equalTo: right).isActive = true
    }
    //   TOTH:
    //    https://github.com/dasher-project/redash/blob/master/Keyboard/foriOS/DasherApp/Keyboard/KeyboardViewController.swift#L129
#endif
    
}
