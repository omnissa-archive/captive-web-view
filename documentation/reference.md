Reference Documentation
=======================
This is the reference documentation for the Captive Web View library. For an
introduction, see the [parent directory](/../) readme file.

**Just notes at the moment.**

# Frequently Asked Questions

## What is a web view?
A web view renders HTML and CSS, and runs JavaScript, just like a browser. The
difference is that a browser is a whole application on its own. A web view is
embedded inside another application, as part of its user interface.

Both Android and iOS offer a web view object for the mobile application user
interface. See the following for reference.

-   For Android: https://developer.android.com/reference/android/webkit/WebView
-   For iOS: https://developer.apple.com/documentation/webkit/wkwebview

Embedded web view objects are typically used to implement in-app browsers, in
which the user can read, or interact with, remote web content without leaving
the application. For example, a mobile app might use a web view to display the
support pages for its service. Those pages would already exist on the service's
web site and would be retrieved and rendered by the embedded web view.

## What is this project for and why?
This project facilitates a captive web view object, that renders local content
from the app's bundled resources, instead of from the Internet. The content
would still be HTML, CSS, and JavaScript, but would be packaged in the
executable.

## Why is there a bridged fetch command, as well as the option to use JavaScript Fetch?
JavaScript (JS) Fetch is part of the HTML 5 standard and should be the first
choice for an HTTP application programming interface (API). However, it has
these limitations.

-   JS Fetch in a web view won't return results from an HTTP server that doesn't
    declare itself as an API, by including the Access-Control-Allow-Origin
    header.

-   JS Fetch doesn't make the server's peer certificate accessible.

The bridged fetch command is there to address those cases. A native HTTP client,
such as Android HttpsURLConnection, will return results from any HTTP server and
has access to the peer certificate.

This is the API of the built-in bridged fetch.

-   Request.

        {
            command: "fetch", parameters: {
                resource: "https://path.of/the/resource", options: {
                    method: "POST or GET for example",
                    body: "JSON string to send as the request body",
                    bodyObject: {
                        key1: value, key2: "value"
                    },
                    headers: {
                        httpHeader1: "value", httpHeader2: "value"
                    }
                }
            }
        }

    If neither `options.body` nor `options.bodyObject` is given then the request
    body will be empty. If both are given, `bodyObject` takes precedence. If
    either is given, HTTP header Content-Type is sent with the value
    "application/json".

-   Response, based on the standard
    [https://developer.mozilla.org/en-US/docs/Web/API/Response](https://developer.mozilla.org/en-US/docs/Web/API/Response)

        {
            ok: true if everything was OK,
            status: Integer code, either an HTTP code or a value less than 200,
            statusText: "HTTP reason from the server, or an Exception class name",
            headers: {
                "HTTP-Header": "value",
                "Other-detail": "value if HTTP headers aren't being returned"
            },
            text: "String of whatever was fetched, raw.",
            json: { ... } or null if the response wasn't JSON,

            peerCertificate {
                DER: "Base 64 encoded",
                length: Integer length in bytes of the decoded DER
            }
        }

# Bridge Interface Notes
The Captive Web View bridging interface works as follows.

-   Web to native:
    -   In the JavaScript code, send an object by calling the library's
        JavaScript sendObject method.
    -   The library converts the object and invokes a callback in the native
        code.
        -   The callback receives a Kotlin JSONObject, or Swift Dictionary, as a
            parameter.
    -   The callback can return a response of the same type.
    -   The library converts the response to a JavaScript object.
    -   The JavaScript sendObject method returns the converted object.

-   Native to web:
    -   In the native code, send a Kotlin JSONObject, or Swift Dictionary,
        by calling the library's native sendObject method.
    -   The library converts the native object to a JavaScript object.
    -   The library invokes a callback in the JavaScript code, and passes
        the converted object as a parameter.
    -   The callback can return a response object.
    -   The library converts the response to a a Kotlin JSONObject, or Swift
        Dictionary instance.
    -   The native sendObject method returns the converted object.

# Structure Notes
Typical structure is as follows.

-   The native user interface (NUI) is either an Activity, for Android, or a
    ViewController, for iOS.

    The NUI for Android is started by being registered as the main and launcher
    activity in the manifest.

    The NUI for iOS is initiated from the application subclass, in the didFinish
    implementation.

    In either case, when the NUI starts it sets itself to occupy the whole
    device screen programmatically. The NUI for Android doesn't use a layout
    XML; the NUI for iOS doesn't use a storyboard.

-   The NUI contains a WebView and no other user interface elements. The WebView
    occupies the whole of the NUI, which in turn occupies the whole of the
    screen, see above.

-   At some point in the application start-up cycle, the WebView loads an HTML
    file, known as mainHTML. The mainHTML file will be in the application
    project.

    This is done by generating a URL for the mainHTML and calling the NUI base
    class URL loading method.

-   The mainHTML file includes a script tag with cpativewebview.js as its `src`
    attribute. The captivewebview.js file is in the Captive Web View library
    project. The WebView or NUI base class serves files from the library assets
    as if they were in the application assets, transparently.

-   The mainHTML file also includes a script tag with inline code that calls the
    CaptiveWebView.whenLoaded method and specifies its main JavaScript module as
    a parameter.

    The whenLoaded method sets the body onload to do the following.

    -   Create the JavaScript end of the bridge to the native code.
    -   Instantiate an instance of the application's main JavaScript module.

    When the main module is instantiated, it is passed a reference to the bridge
    object.

# Platform Notes
-   WKWebView doesn't support WebRTC. This means that the device cameras cannot
    be utilised from the JavaScript layer in an application for iOS or iPadOS.

    This seems to be an acknowledged issue, see the following:  
    [https://bugs.webkit.org/show_bug.cgi?id=185448](https://bugs.webkit.org/show_bug.cgi?id=185448)

    Android WebView supports camera via WebRTC no problem.

-   Android WebView doesn't support speech synthesis.

    It's a defect in Chromium, according to these links:

    -   https://stackoverflow.com/questions/55926880/speechsynthesis-in-android-webview
    -   https://bugs.chromium.org/p/chromium/issues/detail?id=487255

-   The library for iOS doesn't use any dynamic libraries that would make it
    unsafe for use in an App Extension. The relevant build target includes the
    declaration: Allow app extension API only.

    TOTH: https://stackoverflow.com/a/48863451/7657675

-   There seems to be a bug in versions 12.1 and 11 of Xcode. It crashes when
    you add files to an app project, if all the following conditions are met:

    -   The files are added by folder reference, not as a group.
    -   The files aren't under the project directory hierarchy.
    -   The project is open in a workspace.
    -   There is a dependency on a local Swift package.

    See for example:  
    [https://developer.apple.com/forums/thread/661706](https://developer.apple.com/forums/thread/661706)

    There was a workaround to add the files as a group instead of as a folder
    reference. However, the bug is fixed in 12.2 Xcode.

-   The Package.swift file must be in the root of the repository.

    It's possible to edit this file:
    
        swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata
        
    A sub-directory can be specified, like forApple/captive-web-view , but it
    only works in this repository.

    If the package file isn't at the root, then a project that attempts to
    include the package as a remote will fail with this error:

        https://github.com/omnissa-archive/captive-web-view has no Package.swift manifest

    This means that all the other package pieces, like the Source/ and Tests/
    directories, also have be in the root of the repository.

-   The apps and library for Android declare their package names in their
    build.gradle files, in the applicationID and namespace properties, and not
    in their manifests.

    This web page has recommendations.  
    [https://developer.android.com/build/configure-app-module](https://developer.android.com/build/configure-app-module)

    Specifically this.

    >   Keep the application ID the same as the namespace.

# Headless Web View
See the separate [headless.md](headless.md) file for details.

Legal
=====
Copyright 2023 Omnissa, LLC.  
SPDX-License-Identifier: BSD-2-Clause
