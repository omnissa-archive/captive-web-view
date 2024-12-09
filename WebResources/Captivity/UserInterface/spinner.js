// Copyright 2020 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

const spinnerTitle = "Spinner Title"
const pollIntervalMillis = 1000;

class Spinner {
    constructor(bridge) {
        this._bridge = bridge;
        const loading = document.getElementById('loading');
        const builder = new PageBuilder('div', undefined, document.body);

        const header = new PageBuilder('div', undefined, builder.node);
        const middle = this._set_up(builder);
        this._footer = new PageBuilder('div', undefined, builder.node);

        this._message = this._footer.add_node("div", "Getting status ...");
        this._message.classList.add('__message');
        this._get_status();
        const buttonClose = this._footer.add_button("Close");
        this._transcript = PageBuilder.add_transcript();

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "Spinner"});
        };

        buttonClose.addEventListener('click', () => this._send({
            "command": "close"}));

        loading.firstChild.textContent = spinnerTitle;
        header.into(loading);

        this._send({"command": "ready"}).then(this._on_ready.bind(this));
    }

    _set_up(builder) {
        const middle = new PageBuilder('div', undefined, builder.node);
        middle.node.classList.add('__spinner-holder');

        const spinner = middle.add_node('div');
        spinner.classList.add('__spinner');

        return middle;
    }

    _get_status() {
        this._send({"command": "getStatus"})
        .then(response => {
            if (response.message !== undefined) {
                this._message.firstChild.textContent = response.message;
            }
        });
    }

    _transcribe(messageObject) {
        const message = JSON.stringify(messageObject, undefined, 4);
        if (this._transcript === null) {
            console.log(message)
        }
        else {
            this._transcript.add(message);
        }
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

    _on_ready(response) {
        const showLog = response.showLog;
        if (showLog === undefined || showLog) {
            this._footer.into(this._transcript.node);
        }
        else {
            this._transcript = null;
            this._transcribe(response);
        }

        setInterval(this._get_status.bind(this), pollIntervalMillis);
    }
}

export default function(bridge) {
    new Spinner(bridge);
    return null;
}
