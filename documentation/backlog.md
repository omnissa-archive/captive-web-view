Backlog
=======
This is the product backlog for the Captive Web View library. For an
introduction, see the [parent directory](/../) readme file.

-   Error displays for iOS web View like the Android htmlErrorResponse().

    Calling iOS urlSchemeTask.didFailWithError aborts retrieval without showing
    any error in the WKWebView. That's OK for resources but for navigation means
    that there is no visible failure in the web view.

-   Add the meta in JS:

        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    
    Currently it's in the HTML.

-   Construct HTML head fields programmatically, maybe.

-   Maybe a version with automatic scroll-into-view on focus.

    https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView

-   Check if anything from the following code could be used:

    https://github.com/googlearchive/chromium-webview-samples/tree/master/webrtc-example/app/src/main/java/com/google/chrome/android/webrtcsample

-   Apply a colour scheme from the native layer in the web view.

    This could be done in a number of ways.

    -   Use a standard CSS import with a well-known name like
        `appColourScheme.css` in the UI web resources. The native code would
        generate the CSS at run time and serve it as a response.

    -   Static insertion of CSS into any HTML file loaded from the app resources
        or assets. The CSS code would be the same as in the import mechanism.

    -   Send a colour scheme in a JSON object during bridge initialisation. The
        bridge code could then insert an on-the-fly CSS node and populate it
        with CSS rules, also generated on-the-fly. The rules would be the same
        as in the import mechanism. For reference, see:  
        [https://developer.mozilla.org/en-US/docs/Web/API/CSSStyleSheet](https://developer.mozilla.org/en-US/docs/Web/API/CSSStyleSheet)

    Of these mechanisms, static insertion would result in the CSS being present
    earliest in the HTML loading cycle. In an Android web view, the CSS would be
    there before the visual state callback invocation. See:  
    [https://developer.android.com/reference/android/webkit/WebView#postVisualStateCallback(long,%20android.webkit.WebView.VisualStateCallback)](https://developer.android.com/reference/android/webkit/WebView#postVisualStateCallback(long,%20android.webkit.WebView.VisualStateCallback))
    
    It's desirable for the CSS to be in place before the first render of the web
    view so that, for example, styling for dark or light mode will already be
    applied when the web view is drawn for the first time. (The Android visual
    state callback is invoked before any imported CSS has been requested by the
    web view, and way before bridge initialisation.)

    At time of writing, styling isn't guaranteed to be in place before the
    visual state callback and first render. This means that there can be a white
    flash during initial load of an Activity or ViewController, and during
    navigation within a Activity or ViewController. The solution has been to
    make the web view invisible when loading or navigation starts, and then make
    it visible after a short delay, like 400 milliseconds. A better solution,
    for Android, would be to use the visual state callback, if the styling was
    guaranteed to be in place. Following code snippet illustrates use of the
    visual state callback to make a web view visible.
    
        val loadRequest = 1L
        webView.postVisualStateCallback(loadRequest,
            object :android.webkit.WebView.VisualStateCallback() {
                override fun onComplete(requestID: Long) {
                    if (requestID == loadRequest) {
                        webView.visibility = View.VISIBLE
                    }
                }
            }
        )

    However, a solution based on static insertion could involve parsing and
    modifying HTML content in the native layer.

Legal
=====
Copyright 2020 Omnissa, LLC.  
SPDX-License-Identifier: BSD-2-Clause
