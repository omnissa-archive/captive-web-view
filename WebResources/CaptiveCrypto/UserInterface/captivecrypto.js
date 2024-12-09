// Copyright 2020 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

class CaptiveCrypto {
    constructor(bridge) {
        const loading = document.getElementById('loading');
        this._bridge = bridge;

        const builder = new PageBuilder('div', undefined, document.body);
        builder.add_anchor("KeyStore.html", "Native Key Store");
        builder.add_anchor(
            "SubtleCrypto.html", "HTML 5 Subtle Crypto Scratch Code");

        loading.firstChild.textContent = "Captive Cryptography";
        loading.classList.add('loaded');
    }
}

export default function(bridge) {
    new CaptiveCrypto(bridge);
    return null;
}
