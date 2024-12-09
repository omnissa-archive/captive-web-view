# Captive Web View
This repository holds the Captive Web View library code and sample applications.

# Overview
The Captive Web View library facilitates use of web technologies in mobile
applications. It has the following features.

-   Web technologies support.

    The library facilitates use of Web View controls as the container for any of
    the following.
    
    -   Whole application.
    -   Whole user interface.
    -   Part of user interface.
    -   Headless application code.
    
    The user interface, and any other code running in a Web View, would be
    written in HTML5, CSS, and JavaScript.
    
    The Android and iOS versions of a Captive Web View application can share the
    same HTML5, CSS, and JavaScript code.

-   Object bridge.

    The library implements a simple bridge between JavaScript, running in the
    Web View, and Kotlin or Swift code, running natively.

    The bridge can be invoked from either the native end or the JavaScript end, 
    and supports responses.

    The JavaScript ends of the bridge interface use JavaScript objects. The
    native ends use either JSONObject, for Android, or Dictionary, for iOS.

-   Native user interface division.

    The library can be used with applications that divide their user interface
    into multiple Activity or ViewController classes. A different HTML file can
    be associated with each native class.

-   Modern standards from built-in controls.

    The library utilises the built-in WebView, for Android, and WKWebView, for
    iOS. These classes support the latest web standards, such as HTML5 and ES6
    JavaScript. Support is maintained by the respective developer teams, i.e.
    the Chromium and WebKit projects.

The library for Android is written in Kotlin; the library for iOS is written in
Swift. There is also a small amount of JavaScript code in the library.

Captive Web View can be seen as a simple version of platforms like Apache
Cordova and Electron.

# Usage
-   For Android, see the [forAndroid sub-directory](/forAndroid/).
-   For iOS, Catalyst, and native macOS, see the
    [forApple sub-directory](/forApple/).

# Learn More
-   Reference documentation is in the 
    [documentation/reference.md](documentation/reference.md) file.

## Contributing
The Captive Web View project team welcomes contributions from the community.
For more detailed information, refer to the
[contributing.md](contributing.md) file.

Check the [documentation/backlog.md](documentation/backlog.md) file for a list
of work to be done.

License
=======
Captive Web View, is:  
Copyright 2020 Omnissa, LLC.  
And licensed under a two-clause BSD license.  
SPDX-License-Identifier: BSD-2-Clause
