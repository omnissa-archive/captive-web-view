// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

function JSONable(obj, minLayers=0) {
    if (minLayers <= 0) {
        const stringified = JSON.stringify(obj);
        if (stringified !== "{}") {
            // console.log(stringified);
            return obj;
        }
    }
    const jsonAble = {};
    for(let propertyName in obj) {
        // console.log(propertyName, obj[propertyName]);
        jsonAble[propertyName] = JSONable(obj[propertyName], minLayers - 1);
    }
    return jsonAble;
}

function sorting_replacer(omit, key, value) {
    // TOTH: https://stackoverflow.com/a/31102605/7657675
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
        const _return = {};
        Object.keys(value).filter(
            objectKey => !(key === "" && omit.includes(objectKey))
        ).sort().forEach(
            key => _return[key] = value[key]
        );
        return _return;
    }
    return value;
}

// Cheeky constants that are strings but declared without strings being used.
const KEY = {
    // Commands that can be sent to the native layer.
    encipher:null,
    write:null,
    capabilities: null,
    deleteAll: null,
    summariseStore:null,

    // Parameter names used in exchanges with the native layer.
    command:null, // Can't always be used.
    confirm:null,
    secure:null
};
Object.keys(KEY).forEach(key => KEY[key] = key);

const databaseName = "Keys";

const prefix = "CaptiveCrypto ";
function key_item_labels(keySummary) {
    const name = (
        keySummary.name.startsWith(prefix)
        ? keySummary.name.slice(prefix.length)
        : keySummary.name
    );
    return [
        ...(name === "" ? [] : [' "', name, '" ']),
        keySummary.type === "" ? keySummary.storage : keySummary.type
    ];
}

function key_sort_value(keySummary) {
    return [
        ...key_item_labels(keySummary),
        JSON.stringify(keySummary.summary, sorting_replacer.bind(null, []))
    ].join("");
}

class KeyStore {
    constructor(bridge) {
        this._bridge = bridge;
        this._resultCommand = undefined;

        this._page = new PageBuilder('div', undefined, document.body);
        this._build_key_store_panel();
        this._build_add_key_panel();
        this._build_button_panel();
        this._build_result_panel();
        this._transcript = this._page.add_transcript(true);
        this._transcript.node.classList.remove('cwv-transcript');

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {confirm: "KeyStore"});
        };

        this._refresh_keystore()
        .then(() => {
            // Replace the content of the loading h1 with a link back to the
            // first screen of the app.
            const loading = new PageBuilder(document.getElementById('loading'));
            loading.node.firstChild.remove();
            const anchor = loading.add_anchor("Main.html", "Key Store");
            anchor.classList.add("cwv-anchor", "cwv-anchor_back");
        });
    }

    async _refresh_keystore(forResults=false) {
        const response = await this._send(
            {command: KEY.summariseStore}, forResults);

        if (response.results !== undefined) {
            // Setter invocation that reloads the key store items UI.
            this.keyStore = response.results;
        }

        return response;
    }

    async _send(command, forResults=true, andRefresh=true) {
        const response = await this._bridge.sendObject(command)

        if (KEY.secure in response && !response[KEY.secure]) {
            // The `secure` item is a vestige of something Jim was trying in
            // relation to WebRTC in iOS. It's always false, which is maybe
            // worrying so remove it here.
            delete response[KEY.secure];
        }

        if (command.command === KEY.write) {
            if (response.wrote !== undefined) {
                response.results = {wrote: response.wrote};
                delete response.wrote;
            }
        }

        if (response.results === undefined) {
            this._transcribe(response);
        }
        else {
            if (forResults) {
                this.result = response.results;
                this._resultCommand = command.command;
            }
            else if (command.command !== KEY.summariseStore) {
                this._transcribe(response);
            }
        }

        if (andRefresh && command.command !== KEY.summariseStore) {
            this._refresh_keystore();
        }

        return response;
    }

    _transcribe(message) {
        this._transcript.add(JSON.stringify(message, undefined, 4), 'pre');
    }

    _build_result_panel() {
        const builder = new PageBuilder(this._page.add_node('fieldset'));
        const legend = builder.add_node('legend');

        const panel = { display: builder.add_node('textarea') };

        const resultIdentifier = "result";
        Object.entries({
            id:resultIdentifier, name:resultIdentifier, readonly:true,
            rows: 10, cols:45,
            placeholder:"No results yet ..."
        }).forEach(([key, value]) => panel.display.setAttribute(key, value));
        
        const label = PageBuilder.add_node('label', "Results", legend);
        label.setAttribute('for', resultIdentifier);
        // Default in the iOS web view is to select the textarea, and zoom in.
        // That isn't wanted here, so suppress it.
        label.addEventListener('click', event => event.preventDefault());

        panel.writeButton = builder.add_button("Write");
        panel.writeButton.setAttribute('disabled', true);
        panel.writeButton.addEventListener('click', event => {
            this._send({command: "write", parameters: {
                text: this._resultPanel.display.textContent,
                filename: this._resultCommand + ".json"
            }}, true, false)
            .then(() => event.target.setAttribute('disabled', true));
        });

        this._resultPanel = panel;
    }

    get result() { return this._result; }
    set result(result) {
        this._result = result;
        this._resultPanel.display.textContent = JSON.stringify(
            result,
            sorting_replacer.bind(this, [KEY.command, KEY.confirm]),
            4
        );
        this._resultPanel.writeButton.removeAttribute('disabled');
    }

    _build_key_store_panel() {
        const panel = { entries: [] };

        panel.emptyMessage = this._page.add_node('div', "Key store empty");
        panel.emptyMessage.classList.add('kst__key-store-message');

        panel.entriesNode = this._page.add_node('div');

        this._keyStorePanel = panel;
    }

    get keyStore() { return this._keyStore; }
    set keyStore(keyStore) {
        this._keyStore = keyStore;

        const panel = this._keyStorePanel;
        panel.emptyMessage.classList.toggle(
            'kst__key-store-message_empty', keyStore.length <= 0);

        // Add a sort value for every key entry in the key store summary.
        const updatedEntries = keyStore.map(keySummary => {return {
            summary:keySummary, sortValue:key_sort_value(keySummary)
        }}).sort((a, b) => (
            a.sortValue < b.sortValue ? -1 : a.sortValue > b.sortValue ? 1 : 0
        ));

        // Cheeky use of .every() method. An early `return true` serves as a
        // continue would in a for loop.
        updatedEntries.every((storeEntry, index) => {
            const {summary, sortValue} = storeEntry;
            if (index >= panel.entries.length) {
                panel.entries.push(storeEntry);
            }
            else if (sortValue != panel.entries[index].sortValue) {
                panel.entries[index] = storeEntry;
            }
            else {
                // No change from incumbent.
                return true;
            }

            this._new_key_entry(summary, index);
            return true;
        });

        while(panel.entriesNode.children.length > updatedEntries.length) {
            panel.entriesNode.children[updatedEntries.length].remove();
        }
        panel.entries = updatedEntries;
    }

    _new_key_entry(summary, index) {
        const builder = new PageBuilder('fieldset');
        const parent = this._keyStorePanel.entriesNode;
        if (index >= parent.children.length) {
            parent.append(builder.node);
        }
        else {
            parent.children[index].replaceWith(builder.node);
        }
        const legend = [
            `Key ${index + 1}:`, ...key_item_labels(summary)
        ].join("");
        builder.add_node('legend', legend);

        const divButtons = new PageBuilder(builder.add_node('div'));
        const divControls = new PageBuilder(builder.add_node('div'));
        const buttons = [
            divButtons.add_button(), divButtons.add_button("Test")];

        const controls = [

            this._build_key_details_controls(
                buttons[0], divControls, summary, index),

            this._build_key_test_controls(divControls, summary.name, index)

        ];
        const collapsedClass = 'kst__key-controls_collapsed';
        controls.forEach(control => control.classList.add(
            'kst__key-controls', collapsedClass));
        buttons.forEach((buttonBuild, buttonIndex) => {
            buttonBuild.classList.add(
                'kst__key-button', 'kst__key-button_collapsed');
            
            buttonBuild.addEventListener('click', () => {
                const collapsed = controls[buttonIndex].classList.contains(
                    collapsedClass);

                buttons.forEach(
                    (button, clickedIndex) => button.classList.toggle(
                        'kst__key-button_collapsed',
                        (clickedIndex != buttonIndex) || !collapsed)
                );

                controls.forEach(
                    (control, controlIndex) => control.classList.toggle(
                        collapsedClass,
                        (controlIndex != buttonIndex) || !collapsed
                    )
                );
            })
        });

        return builder;
    }

    _build_key_details_controls(button, builder, summary, index) {
        const label = PageBuilder.add_node('label', "Details", button);

        const textarea = builder.add_node('textarea');
        const identifier = `key-details-${index}`;
        Object.entries({
            id:identifier, name:identifier, 
            readonly:true, rows: 10, cols:50
        }).forEach(([key, value]) => textarea.setAttribute(key, value));
        textarea.textContent = JSON.stringify(summary, undefined, 4);
        label.setAttribute('for', identifier);
        // Default in the iOS web view is to select the textarea, and zoom in.
        // That isn't wanted here, so suppress it.
        label.addEventListener('click', event => event.preventDefault());

        return textarea;
    }

    _build_key_test_controls(builder, alias, index) {
        const identifier = `key-test-${index}`;
        const testPanel = new PageBuilder(builder.add_node('div'));

        const sentinelInput = testPanel.add_input(
            identifier, "Sentinel:", true, "text");
        sentinelInput.inputNode.setAttribute('size', 6);

        const runButton = testPanel.add_button("Run");
        runButton.setAttribute('disabled', true);

        sentinelInput.inputNode.addEventListener('input', () => {
            if (sentinelInput.value.length > 0) {
                runButton.removeAttribute('disabled');
            }
            else {
                runButton.setAttribute('disabled', true);
            }
        });

        runButton.addEventListener('click', () => this._send({
            command: KEY.encipher, parameters: {
                sentinel: sentinelInput.value,
                alias: alias
            }
        }, true, false));

        return testPanel.node;
    }

    _build_add_key_panel() {
        const builder = new PageBuilder(this._page.add_node('fieldset'));
        builder.add_node('legend', "Add Key");

        const nameInput = builder.add_input('alias', "Alias:", true, "text");
        nameInput.inputNode.setAttribute('size', 6);
        nameInput.node.classList.add('kst__key-alias');

        const pairButton = builder.add_button("Key Pair");
        pairButton.addEventListener(
            'click', () => this._send_add_key("generatePair", nameInput));

        const keyButton = builder.add_button("Key");
        keyButton.addEventListener(
            'click', () => this._send_add_key("generateKey", nameInput));
    }

    _send_add_key(command, input) {
        return this._send({command: command, parameters: {alias: input.value}})
        .then(response => {
            input.value = "";
            return response;
        });
    }

    _build_button_panel() {
        const builder = new PageBuilder(this._page.add_node('div'));
        builder.node.classList.add('kst__button-panel');

        const refreshButton = builder.add_button("Refresh");
        refreshButton.addEventListener(
            'click', () => this._refresh_keystore(true));

        const capButton = builder.add_button("Capabilities");
        capButton.addEventListener(
            'click', () => this._send({command:KEY.capabilities}, true, false));

        const clearButton = builder.add_button("Delete All");
        clearButton.addEventListener('click', () => {
            this._send({command:KEY.deleteAll})
            .then(() => this._delete_web_view_key())
            .then(deleteResult => this.result = Object.assign(
                (!this.result) ? {} : this.result, {indexedDB:deleteResult}));
            // The send here will resolve after the result has been set into
            // `this.result`, unless this is being run against the Python
            // testing back end. In that case, there won't have been any result
            // and this.result will be null. The above Object.assign line above
            // will create an empty object if needed.
        });
        
        const webViewKeyButton = builder.add_button("Store Web View Key");
        webViewKeyButton.addEventListener('click', event => {
            event.target.setAttribute('disabled', true);
            this._generate_web_view_key()
            .then(() => event.target.removeAttribute('disabled'));
        });
    }

    _generate_web_view_key() {
        return new Promise((resolve, reject) => {
            const crypto = window.crypto.subtle;
            if (crypto) {
                resolve(crypto);
            }
            else {
                reject(`Subtle Crypto: ${crypto}.`);
            }
        })
        .then(crypto =>
            crypto.generateKey({
                name: "RSA-OAEP",
                modulusLength: 4096,
                publicExponent: new Uint8Array([1, 0, 1]),
                hash: "SHA-256"
            }, false, ["encrypt", "decrypt"])
        )
        .catch(error => this._transcribe({"error": String(error)}))
        .then(keyPair => new Promise((resolve, reject) => {
            const request = indexedDB.open(databaseName, 1);

            request.onerror = event => reject({
                store: "open error", event: String(event)
            });

            // Create the schema, if needed.
            request.onupgradeneeded = event =>
                event.target.result.createObjectStore(
                    databaseName, {keyPath: "identifier"});
        
            // The resolve and reject functions are passed as parameters so
            // that the _store_key method can finalise the Promise.
            request.onsuccess = event => 
                this._store_key(resolve, reject, event, keyPair);
        }))
        .then(result => {
            this.result = result;
            this._resultCommand = "generate_web_view_key";

            // Refresh the key store UI in case a native key has been added as a
            // result of the storage of a SubtleCrypto key. Observations so far:
            //
            // -   Android doesn't add to the Android Key Store.
            // -   iOS adds a keychain item: WebCrypto Master Key.
            this._refresh_keystore();

            return result;
        })
        .catch(error => {
            this._transcribe(error);
            return null;
        });
    }

    _store_key(resolve, reject, eventOpen, keyPair) {
        const keyDescription = JSONable(keyPair, 1);
        const database = eventOpen.target.result;
        const transaction = database.transaction(database.name, "readwrite");
        const store = transaction.objectStore(database.name);

        try {
            // If you comment out the identifier key and value, in order to
            // generate an error, the .put will throw immediately instead of
            // invoking its onerror handler.
            const putRequest = store.put({"identifier":1, "key":keyPair});

            putRequest.onerror = domException => {
                database.close();
                reject({
                    store: "put error",
                    key: keyDescription,
                    code: domException.code,
                    message: domException.message,
                    name: domException.name,
                    domException: String(domException)
                });
            };
            putRequest.onsuccess = event => {
                database.close();
                resolve({
                    store: "OK",
                    result: event.target.result,
                    key: keyDescription
                });
            };
        }
        catch(exception) {
            database.close();
            reject({
                store: "caught error",
                key: keyDescription,
                code: exception.code,
                message: exception.message,
                name: exception.name,
                exception: String(exception)
            });
        }
    }

    _delete_web_view_key() {return new Promise((resolve, reject) => {
        const request = indexedDB.deleteDatabase(databaseName);
        request.onerror = domException => reject({
            database: "delete error",
            code: domException.code,
            message: domException.message,
            name: domException.name,
            domException: String(domException)
        });
        request.onsuccess = event => resolve({
            // The oldVersion will be 0 if there was no database, or the version
            // number otherwise.
            database: "delete OK", version: event.oldVersion
        });
    });}
}

export default function(bridge) {
    PageBuilder.add_css_file("keystore.css");
    new KeyStore(bridge);
    return null;
}
