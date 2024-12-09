// Copyright 2019 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

class Secondary {
    constructor(bridge) {
        this._bridge = bridge;
        const loading = document.getElementById('loading');

        const builder = new PageBuilder('div', undefined, document.body);
        builder.add_node(
            'div', "This page loads in a separate Activity or ViewController.");
        builder.add_node(
            'div', "Return by tapping Close, or the Android back button.");
        const buttonClose = builder.add_button("Close");
        this._transcript = builder.add_transcript(false);

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "Secondary"});
        };

        buttonClose.addEventListener('click', () => this._send({
            "command": "close"}));

        loading.firstChild.textContent = "Secondary";

        this._send({"command": "ready"});
    }

    _transcribe(message) {
        this._transcript.add(JSON.stringify(message, undefined, 4));
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
}

export default function(bridge) {
    new Secondary(bridge);
    return null;
}
