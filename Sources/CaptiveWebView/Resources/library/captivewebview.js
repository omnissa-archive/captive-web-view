// Copyright 2019 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

// The script tag that includes this file must be inside the HTML body, so that
// document.body isn't null and its onload listener can be used to kick off
// everything.

// Declare the bridge object here but don't set it. Setting is
// platform-specific, as follows.
//
// -   The Kotlin back end sets it, by calling addJavascriptInterface. Declaring
//     the variable isn't necessary for the Kotlin back end but makes the JS
//     appear consistent here.
// -   The Swift layer doesn't set it, which is part of how this code detects
//     what type of back end is in use and then selects a Bridge subclass.
//
// This is a global variable, and has to be!
var commandBridge;

// It'd be nice to use the import statement like this:
//
//     import main from "./demonstrationapplication.js";
//     document.body.onload = function() {
//       console.log("Main ...");
//       main(bridge);
//       console.log("Main done.");
//     };
//
// That would require this JS file to be embedded with type="module", which
// seemed to prevent the Android JavaScript bridge from working. The
// `commandBridge` var seemed always to be undefined.
//
// So instead, the import() function is used, see below. Interesting note is
// that the imported file can itself use the import statement, no problem.

class CaptiveWebView {
    constructor(mainJS) {
        self._mainJS = mainJS;
    }
    
    load() {
        const httpPage = (
            window.location.protocol === "http:" ||
            window.location.protocol === "https:"
        );
        const wkHandler = (
            window && window.webkit && window.webkit.messageHandlers &&
            window.webkit.messageHandlers.messageBridge
        ) ? window.webkit.messageHandlers.messageBridge : undefined;
        
        return Promise.all([
            import("./" + self._mainJS), import("./bridge.js")]
        ).then(([mainModule, bridgeModule]) => {
            let bridge;
            if (commandBridge === undefined) {
                if (httpPage || wkHandler) {
                    // See comment in bridge.js about why the Message bridge
                    // isn't used.
                    commandBridge = {};
                    bridge = new bridgeModule.Post(commandBridge);
                }
            }
            else {
                bridge = new bridgeModule.Wrapped(commandBridge);
            }
            const main = mainModule.default(bridge);
            if (main !== null) {
                console.log(main);
            }
            return bridge;
        })
        .catch(error => console.log(`Couldn't import main JS: "${error}".`));
    }

    static whenLoaded(mainJS) {
        document.body.onload = function() {
            new CaptiveWebView(mainJS).load();
        };
    }
}
