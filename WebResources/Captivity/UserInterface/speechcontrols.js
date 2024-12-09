// Copyright 2020 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause
//
// Original speech synthesis code copied from this article and the linked
// repository:  
// https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis
// License is: CC0 1.0 Universal.
//
// The repository is licensed under Creative Commons Zero v1.0 Universal and so
// unencumbered by copyright, see:  
// https://github.com/mdn/web-speech-api/blob/master/LICENSE

import PageBuilder from "./pagebuilder.js";
import Speech from "./speech.js";

class SpeechControls {
    constructor(bridge) {
        this._bridge = bridge;
        this._speech = new Speech()
    }

    load(rootID) {
        const root = document.getElementById(rootID);
        if (root === null) {
            return;
        }
        const builder = new PageBuilder(root);
        // const form = builder.add_node('form');
        const say = builder.add_input('input-text', "Say:");
        
        this._voiceSelect = new PageBuilder(builder.add_node('select'));

        const speakButton = builder.add_button("Speak");
        speakButton.setAttribute('disabled', true);
        speakButton.addEventListener('click', () => {
            const voiceIndex = this._voiceSelect.node.selectedIndex;
            this._speech.speak(say.value, voiceIndex);
        });

        this._speech.initialise(speech => {
            this._voiceSelect.remove_childs();
            speech.voices.forEach(voice => {
                // console.log(voice.lang, voice.default, voice.name);
                this._voiceSelect.add_node(
                    'option', `${voice.name} (${voice.lang})`);
            });
            speakButton.removeAttribute('disabled');
        });
        
        // var inputForm = document.querySelector('form');
        // var inputTxt = document.querySelector('.txt');
        // // var voiceSelect = document.querySelector('select');
        
        // var pitch = document.querySelector('#pitch');
        // var pitchValue = document.querySelector('.pitch-value');
        // var rate = document.querySelector('#rate');
        // var rateValue = document.querySelector('.rate-value');
    }

}

export default function(bridge) {
    const speechControls = new SpeechControls(bridge);
    speechControls.load("user-interface");
    return speechControls;
}
