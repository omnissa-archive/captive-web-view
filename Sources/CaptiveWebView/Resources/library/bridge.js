// Copyright 2019 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

// This file contains a number of classes that implement the same protocol. The
// protocol is for bridging between the JS layer and the native, Kotlin or
// Swift, layer.
//
// The protocol consists of the following.
//
// -    sendObject(command) method.
//
//      Sends a command JavaScript object to the native layer, where it is
//      received by a handler. The handler returns another object, the response.
//      This method returns a Promise that resolves to the response object from
//      the handler.
//
// -    receiveObjectCallback property.
//
//      Set this to the callback that is invoked to receive a command object
//      from the native layer. The callback must return an object, which is
//      passed back as a response to the native caller.

class Bridge {
    constructor(bridgeObject) {
        this._bridgeObject = bridgeObject;

        this.bridgeObject.receiveObject = command => {
            command.failed = 'Bridge error: receiveObjectCallback not set.';
            return command;
        };
    }

    get bridgeObject() {
        return this._bridgeObject;
    }

    get receiveObjectCallback() {
        return this._bridgeObject.receiveObject;
    }
    set receiveObjectCallback(receiveObjectCallback) {
        this._bridgeObject.receiveObject = receiveObjectCallback;
    }
}

// Wrapped bridge, used by the Android back end.
//
// This type of bridge is constructed from an object that should have been
// declared as a var elsewhere. The object must have been set by the Kotlin
// layer having called the addJavascriptInterface method of the WebView class.
// The object must have a sendString() method. See also the captivewebview.js
// file.
export class Wrapped extends Bridge {
    sendObject(command) {
        return Promise.resolve(
            this.bridgeObject.sendString(JSON.stringify(command))
        )
        .then(response => JSON.parse(response))
        .catch(exception => {return {"exception": "" + exception};});
    }
}

// Post bridge, used by iOS and the Python testing back end.
//
// This bridge works by sending an HTTP POST request, with the JavaScript Fetch
// API. The request and its body are handled by the back end, which responds as
// if to an HTTP POST request.
//
// This mechanism isn't used on Android because the POST body isn't available to
// the handler, WebViewClient. Anyway, Android has a proper JavaScript bridge
// capability that is easier to code, see the Wrapped class, above.
export class Post extends Bridge {

    /* How opening a different page works ...

    The user of sendObject sends a command like:

        {
            "command": "load",
            "parameters": {
                "page": "specification like set_password"
            }
        }

    The Android and iOS back ends will take care of that by loading a new web
    view control in the user interface easy. The Python back end can't do that
    so it sends a 307 redirect. The only way to make that work seems to be to
    specify redirect:manual, so that this code actually gets the redirect, and
    then set the document.location to load the page.
    */

    sendObject(command) {
        return fetch('/bridge', {
            "method":'POST',
            "body":JSON.stringify(command),
            "redirect": "manual"
        }).then(Post.postResult)
        .catch(exception => {
            if (exception === "opaqueredirect") {
                const location = command.parameters.page + ".html";
                // Setting the location should throw out any JS code that's in
                // progress but just in case and for neatness, return a message
                // here.
                document.location = location;
                exception = `Redirecting to "${location}".`;
            }
            return {"exception": "" + exception};
        });
    }
    
    static postResult(response) {return (
        // Catch redirects from the Python back end and throw them back to
        // sendObject, above, which has the command parameters and can execute
        // the redirection.
        response.type === "opaqueredirect" ?
        Promise.reject(response.type) :

        // The iOS Swift end responds by calling as follows.
        //
        //     urlSchemeTask.didReceive(URLResponse(...)))
        //
        // This seems to result in ok:false and status:0 in the fetch
        // response. The JSON data is fine though.
        response.ok || response.status === 0 ?
        response.json() :
        response.text().then(text => Promise.reject(
            `Fetch error ok:${response.ok}` +
            ` status:${response.status} statusText:${response.statusText}` +
            ` body"${text}"`))
    );}
}

// The Message bridge could be used to send commands to an iOS WKWebView
// WKScriptMessageHandler implementation. However, that interface doesn't
// support return values, from the Swift layer back here to the JS layer. For
// that reason, this interface isn't used for iOS WKWebView. Instead, the Post
// bridge, above, is used.
export class Message {
    constructor(wkHandler) {
        this._wkHandler = wkHandler;
    }
    
    sendObject(command) {
        this._wkHandler.postMessage(command);
        return Promise.resolve({"WKScriptMessageHandler": command});
    }
}