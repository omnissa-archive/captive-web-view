// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

class Main {
    constructor(bridge) {
        const loading = document.getElementById('loading');
        this._bridge = bridge;
        this._builder = new PageBuilder('div', undefined, document.body);

        this._transcript = PageBuilder.add_transcript(document.body, true);

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "Main"});
        };
        
        this._add_buttons();

        loading.firstChild.textContent = "Fetch Test";

        bridge.sendObject({"command": "ready"})
        .then(response => this._transcribe(response))
        .catch(error => this._transcribe(error));
    }
    
    _add_buttons() {
        [
            ["JSON object OK.", "https://httpbin.org/get"],
            ["Not a URL fail.", "Not a URL"],
            ["Bad address.", "https://badaddress"],
            ["GET w/body iOS fail.", "https://example.com", {bodyObject:{}}],
            ["HTML page, fails JSON parsing.", "https://example.com"],
            ["404 and empty body.", "https://httpbin.org/status/404"],
            ["400 and error message in HTML.", "https://client.badssl.com/"],
            ["404 and the usual front page HTML."
             + " Note that 404 isn't a special value for the"
             + " example.com server.",
             "https://example.com/404"
             ]
        ].forEach(([result, url, options]) => {
            const parameters = {};
            if (url === undefined) {
                url = "Undefined";
            }
            else {
                parameters.resource = url;
            }

            this._builder.add_node('span', result);

            this._builder.add_button(url).addEventListener('click', event => {
                event.target.disabled = true;
                this._send({command: "fetch", parameters: parameters})
                .then(response => {
                    event.target.disabled = false;
                })
                .catch(error => {
                    event.target.disabled = false;
                });
            });

            if (options !== undefined) {
                parameters.options = options;
                this._builder.add_node(
                    'pre', JSON.stringify(options, undefined, 4));
            }

            this._builder.add_node('hr');
        });
    }

    _send(object_) {
        return (
            this._bridge ?
            this._bridge.sendObject(object_) :
            Promise.reject(new Error("No Bridge!"))
        ).then(response => {
            this._transcribe(response);
            return response;
        })
        .catch(error => {
            this._transcribe(error);
            return error;
        });
    }

    _transcribe(message) {
        this._transcript.add(JSON.stringify(message, undefined, 4), 'pre');
    }
}

export default function(bridge) {
    new Main(bridge);
    return null;
}
