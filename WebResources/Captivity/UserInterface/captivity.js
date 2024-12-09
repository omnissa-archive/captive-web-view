// Copyright 2022 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

class Captivity {
    constructor(bridge) {
        const loading = document.getElementById('loading');
        this._bridge = bridge;
        this._panels = [];
        this._builder = new PageBuilder('div', undefined, document.body);
        // Initial location of the transcript is the body. This is changed later
        // when it becomes a panel.
        this._transcript = PageBuilder.add_transcript(document.body, true);

        this._bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "Captivity"});
        };

        this._panelHolder = new PageBuilder(this._builder.add_node('div'));
        const focusInput = this._panel_basic(this._new_panel(
            "Basic and Focus"));
        this._panel_login(this._new_panel("Dummy Login"));
        this._panel_demonstrations(this._new_panel("Web View Demonstrations"));
        this._panel_page_builder(this._new_panel("Page Builder Samples"));
        this._panel_diagnostic(this._new_panel("Diagnostic"));
        this._new_panel(null, this._transcript);
        this._selectors_build();

        loading.firstChild.textContent = "Captivity";
        this._builder.into(loading, false);

        // The back end for the focus command must do whatever is needed to
        // cause the keyboard to be displayed:
        //
        // -   For Android, there's a few lines of system service code, which
        //     are in the captivewebview Activity class, in the focusWebView
        //     method.
        // -   On iOS, there's just a call to the view.becomeFirstResponder
        //     method.
        //
        // This never worked on iOS until it was changed to be in an
        // asynchronous block, like it is now. At some point even that stopped
        // working on iOS.  
        // Most of it works on Catalyst. The focussed field does receive
        // keyboard input. However, the cursor isn't shown in the field until
        // the user types something.
        this._send({"command": "ready"})
        .then(() => {
            focusInput.focus();
            this._send({"command": "focus"});
        });
    }

    _new_panel(label, panel) {
        if (panel === undefined) {
            panel = new PageBuilder('fieldset');
        }
        panel.add_classes('inactive');

        if (label !== null) {
            const legend = panel.add_node('legend');
            legend.append(label);    
        }

        this._panelHolder.node.append(panel.node);
        this._panels.push(panel);

        return panel;
    }

    _panel_basic(panel) {
        const buttonA = panel.add_button("Command A");
        const buttonJSFetch = panel.add_button("JS Fetch");
        const buttonBridgedFetch = panel.add_button("Bridged Fetch");
        const focusInput = panel.add_input('focus', "Default focussed:");
        panel.add_node('span', "User interfaces: ");
        const buttonSecondary = panel.add_button("Secondary");
        const buttonSpinner = panel.add_button("Spinner");

        buttonA.addEventListener('click', () => {
            this._send({"command": "A"});
            focusInput.value = "";
        });
        buttonJSFetch.addEventListener('click', (event) => {
            event.target.disabled = true;
            fetch(focusInput.value)
            .then(response => {
                this._transcribe({ fetchResponse:`${response}` });
                event.target.disabled = false;
            })
            .catch(error => {
                this._transcribe({
                    fetchError: `${error}`,
                    name: error.name,
                    message: error.message,
                    cause: error.cause
                });
                event.target.disabled = false;
            });
        });
        buttonBridgedFetch.addEventListener('click', (event) => {
            event.target.disabled = true;
            let resource = focusInput.value;
            if (resource === "") {
                resource = "https://example.com";
            }
            this._send({command: "fetch", parameters: {
                resource: resource
            }})
            .then(response => {
                event.target.disabled = false;
            })
            .catch(error => {
                event.target.disabled = false;
            });
        });
        buttonSecondary.addEventListener('click', () => {
            this._send(
                {"command": "load", "parameters": {"page": "Secondary"}});
        });
        buttonSpinner.addEventListener('click', () => {
            this._send(
                {"command": "load", "parameters": {"page": "Spinner"}});
        });

        return focusInput.inputNode;
    }

    _panel_login(panel) {
        // Chrome logs a warning if a password type input isn't within a form.
        const form = new PageBuilder(panel.add_node('form'));

        const plainInput = form.add_input('plain', "Plain Input:");
        const secretInput = form.add_input(
            'secret', "Secret Input:", true, "password");
        const buttonLogIn = form.add_button("Log in");
        buttonLogIn.onclick = () => {
            this._send({
                "command": "login",
                "plain":plainInput.value,
                "secret":secretInput.value
            });
            plainInput.value = "";
            secretInput.value = "";
        };

        return form;
    }

    _panel_demonstrations(panel) {
        panel.add_node(
            'div', "These pages open in this Activity or View Controller.");
        panel.add_anchor("three.html", "Three JS for WebGL");
        panel.add_anchor("grid.html", "Grid with changing colour");
        panel.add_anchor("embeddedSVG.html", "Embedded SVG Images");
        panel.add_anchor("camera.html", "Camera");
        panel.add_anchor("speech.html", "Speech");
        
        const speechButton = panel.add_button("Load Speech");
        speechButton.addEventListener('click', () => {
            this._send({"load": "speech.html"});
        })
    }

    _panel_page_builder(panel) {
        const buttonProgress = panel.add_button("Start");
        const progress = panel.add_progress();

        let interval;
        buttonProgress.addEventListener('click', () => {
            // The progress value mustn't be set before the progress bar is
            // visible. If it is, the step width sizes will be calculated too
            // large and the bar will be wider than its container.
            if (progress.value === undefined) {
                progress.value = [0, 0, 0, 0];
            }
            if (interval === undefined) {
                interval = setInterval(() => {
                    const valueArray = progress.value.slice();
                    let increment = 7 * valueArray.length;
                    let filled = 0;

                    function array_increment() {
                        for(const index of valueArray.keys()) {
                            valueArray[index] += increment;
                            if (valueArray[index] > 100) {
                                increment = valueArray[index] - 100;
                                valueArray[index] = 100;
                                filled += 1;
                            }
                            else {
                                increment = 0;
                                break;
                            }
                        }
                    }

                    array_increment();
                    if (increment > 0) {
                        for(const index of valueArray.keys()) {
                            valueArray[index] = 0;
                        }
                        array_increment();
                    }
                    progress.value = valueArray;
                    progress.set_step_colour(
                        filled > 1 ? '#33dd33' : // Green.
                            filled < 1 ? '#cc3232' : // Red.
                            '#e7b416' // Amber.
                    );
                }, 500);
                buttonProgress.firstChild.nodeValue = "Stop";
            }
            else {
                clearInterval(interval);
                interval = undefined;
                buttonProgress.firstChild.nodeValue = "Resume";
            }
        });

    }

    _panel_diagnostic(panel) {
        panel.add_node('div', "Dark mode.").classList.add('dark-mode-only');
        panel.add_node('div', "Light mode.").classList.add('light-mode-only');

        const innerHeightDiv = new PageBuilder(panel.add_node('div'));
        innerHeightDiv.add_node('span', "Window innerHeight:");
        const innerHeightSpan = innerHeightDiv.add_node('span');
        const innerHeightText = document.createTextNode("innerHeight here");
        innerHeightSpan.append(innerHeightText);

        const innerWidthDiv = new PageBuilder(panel.add_node('div'));
        innerWidthDiv.add_node('span', "Window innerWidth:");
        const innerWidthSpan = innerWidthDiv.add_node('span');
        const innerWidthText = document.createTextNode("innerWidth here");
        innerWidthSpan.append(innerWidthText);

        panel.add_input('dummy', "Tap to show keyboard:")

        const check_size = () => {
            innerWidthText.nodeValue = String(window.innerWidth);
            innerHeightText.nodeValue = String(window.innerHeight);
        };
        window.addEventListener('resize', check_size);
        const sizeButton = panel.add_button("Get");
        sizeButton.addEventListener('click', check_size);
        PageBuilder.prevent_focus(sizeButton);
        check_size();
    }

    _selectors_build() {
        // const holder = new PageBuilder(this._panelHolder.add_node('div'));
        const holder = new PageBuilder(this._builder.add_node('div'));
        holder.add_classes('selectors')
        this._selectors = [];
        for (const targetIndex of this._panels.keys()) {
            const div = new PageBuilder(holder.add_node('div'));
            const button = div.add_button(
                targetIndex == this._panels.length - 1 ? "log" :
                String(targetIndex + 1));
            button.onclick = () => this._select(targetIndex);
            this._selectors.push(button);
        }
        this._select(0);
    }
    _select(index) {
        for (const [panelIndex, panel] of this._panels.entries()) {
            panel.node.classList.toggle('inactive', panelIndex !== index);
            this._selectors[panelIndex].classList.toggle(
                'selected', panelIndex === index);
        }
        
        if (index === 0) {
            const focusInput = document.getElementById("focus");
            focusInput.focus();
        }
    }

    _transcribe(message) {
        this._transcript.add(JSON.stringify(message, undefined, 4), 'pre');
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
    new Captivity(bridge);
    return null;
}
