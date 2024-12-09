// Copyright 2019 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

class Main {
    constructor(bridge) {
        const loading = document.getElementById('loading');

        this._transcript = document.createElement('div');
        document.body.append(this._transcript);

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "Main"});
        };

        loading.firstChild.textContent = "Skeleton";

        bridge.sendObject({"command": "ready"})
        .then(response => this._transcribe(response))
        .catch(error => this._transcribe(error));
    }

    _transcribe(message) {
        const pre = document.createElement('pre');
        pre.append(JSON.stringify(message, undefined, 4));
        this._transcript.append(pre);
    }
}

export default function(bridge) {
    new Main(bridge);
    return null;
}
