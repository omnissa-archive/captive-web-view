// Copyright 2020 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

class Headless {
    constructor(bridge) {
        this._bridge = bridge;

        // Diagnostic options.
        //
        // Don't delete Go Rest user after creation. This will cause the next
        // user creation to fail due to duplicate email address. That in turn
        // triggers the deletion of all matching users.
        this._dontDelete = false;

        // First tranche of code is only here to build the diagnostic UI.
        this._token = this._add_input(
            'Token', "Paste in your go-rest Access Token");

        document.body.append(document.createElement('hr'))

        this._add_command_button('SWAPI', {
            api:'star-wars', path:['people', 3]
        });

        this._add_command_button('go-rest GET', {
            api:'go-rest', path:['users', 20]
        });
        this._add_command_button('go-rest 401', {
            method:"POST", api:'go-rest', path:['users']
        });
        // Query parameter isn't supported by Go Rest.
        //
        // >   https://gorest.co.in/ says this:  
        // >   This API supports only HTTP Bearer Tokens
        //
        // Code is left here in case it's useful for another API later.
        //
        // this._add_command_button('go-rest query parameter', {
        //     method:"POST", api:'go-rest', path:['users'],
        //     'query-parameter': 'access-token'
        // });
        this._add_command_button('go-rest basic', {
            method:"POST", api:'go-rest', path:['users'], 'basic-auth': 'Bearer'
        });

        this._hr = document.createElement('hr');
        document.body.append(this._hr);
        // End of main tranche of UI.

        // Entry point for commands received from the native layer.
        this._bridge.receiveObjectCallback = command => Object.assign(
            this._command(command), {"confirm": "Main"});

        // Load secrets here, and for the native layer.
        import("./secrets.js")
        .then(secrets => {
            // Copy the token into the input field.
            this._token.value = secrets.default.token;

            // Send the token to the native layer.
            this._bridge.sendObject({"token": this._token.value});
        })
        .catch(error => {
            const message = `No secrets found ${error}`;
            this._transcribe({error:message});
            this._bridge.sendObject({"noToken": message});
        });

        // Next line is also for the diagnostic UI though.
        document.getElementById('loading').firstChild.textContent = "Headless";

        // Send the ready notification to the native layer.
        this._bridge.sendObject({"command": "ready"})
        .then(response => this._transcribe(response));

        // Next line is also for the diagnostic UI though.
        this._token.focus();
    }

    _add_input(label, title) {
        const form = document.createElement('form');

        const element = document.createElement('input');
        element.setAttribute('name', label);
        element.setAttribute('type', 'password');
        element.setAttribute('placeholder', title);
        element.setAttribute('size', title.length + 4);
        element.setAttribute('autocomplete', 'one-time-code');

        const labelElement = document.createElement('label');
        labelElement.append(`${label}:`);
        labelElement.setAttribute('for', label);

        form.append(labelElement, element);
        document.body.append(form);
        return element;
    }

    _add_command_button(label, command) {
        const button = document.createElement('button');
        button.append(label);
        button.setAttribute('type', 'button');
        button.addEventListener('click', () => this._command(command));
        document.body.append(button);
        return button;
    }

    _transcribe(result) {
        const pre = document.createElement('pre');
        pre.append(JSON.stringify(result, undefined, 4));
        this._hr.insertAdjacentElement('afterend', pre);
    }

    // Process one command, either from the native layer, or from a button here.
    _command(command) {
        // Create a standard Request object.
        const request = this._build_request(command);

        // Copy the url back into the command, which will be returned to the
        // native layer.
        command.url = request.url;
        this._transcribe({command:command});

        setTimeout(() => {
            // Actual Fetch and other processing.
            this._request(request)
            .then(result => {
                this._transcribe(result);
                this._bridge.sendObject(result);
            });
        }, 0);
        // console.log('after time out.')

        return command;
    }

    // Create a standard Request object from a command dictionary.
    _build_request(command) {
        // Convenience variable for the corresponding dictionary entry for the
        // API to which the command relates.
        const base = Headless.apis[command.api];

        // Assemble the HTTP header list.
        const headers = new Headers(base.headers);
        [command.headers].filter(
            headerObject => headerObject !== undefined
        ).forEach(headerObject => {
            Object.entries(headerObject).forEach(
                ([key, value]) => headers.set(key, value)
            );
        });
        if ('basic-auth' in command) {
            headers.set(
                'Authorization',
                [command['basic-auth'], this._token.value].join(" ")
            );
        }

        // Assemble the URI.
        //
        // It seems that you can't create a URL from nothing. This code starts
        // with the document URL, which will usually be kind of a bogus value
        // pointing to https:localhost, on Android, or local:, on iOS.
        //
        // Every part of the URL then gets replaced, so it should be OK.
        const uri = new URL(document.URL);
        uri.protocol = base.protocol;
        uri.hostname = base.hostname;
        uri.port = "";
        this._transcribe({port: uri.port});
        uri.pathname = [...base.path, ...command.path].join('/');
        if ('query-parameter' in command) {
            uri.searchParams.append(
                command['query-parameter'], this._token.value);
        }
        if (command.parameters !== undefined) {
            Object.entries(command.parameters).forEach(
                ([key, value]) => uri.searchParams.append(key, value)
            );
        }

        // Finally, instantiate and return a Request object.
        return new Request(
            uri, {method: command.method, cache: 'no-cache', headers:headers});
    }

    // Generate a JSON-able object from a Request instance.
    _request_JSON(request) {
        return {
            method: request.method,
            url: request.url,
            headers: [...request.headers.entries()]
        };
    }

    // Process one HTTP request.
    //
    // The request will have been generated by the _command method, which wraps
    // this processing.
    //
    // This method takes different assumed actions depending on the request
    // method and destination.
    async _request(request) {
        let errorMessage;

        if (request.method === "GET") {
            return await this._fetch_JSON(request);
        }

        if (request.method === "POST") {
            const uri = new URL(request.url);
            if (
                (
                    uri.pathname.endsWith("/users") 
                    || uri.pathname.endsWith("/users/")
                )
                && uri.hostname === Headless.apis['go-rest'].hostname
             )  {
                return this._fetch_post_delete(request)
                .catch(error => {return {error:`${error}`}});
            }
            errorMessage = {
                message: "Unknown POST combination.",
                request: {pathname: uri.pathname, hostname: uri.hostname},
                known: {hostname: Headless.apis['go-rest'].hostname}
            };
        }

        if (errorMessage === undefined) {
            errorMessage = (
                request.method === undefined ? {
                    message: "No `method` ."
                } : {
                    message: "Unknown method.",
                    method: request.method
                }
            );
        }
        return {error:errorMessage, request:this._request_JSON(request)};
    }

    // Convenience method to send a request and get the JSON body.
    //
    // This method doesn't throw. Instead, it returns an object with an `error`
    // property.
    async _fetch_JSON(request) {
        let response;
        try {
            response = await fetch(request);
        }
        catch(error) {
            // console.log(error);
            return {
                error:`${error}`,
                request:this._request_JSON(request)
            };
        }

        if (!response.ok) {
            return {
                error: {
                    status: response.status,
                    statusText:response.statusText
                },
                request:this._request_JSON(request)
            }
        }

        try {
            return {
                ok:response.ok, body:await response.json(),
                status:response.status, statusText:response.statusText,
                request:this._request_JSON(request)
            };
        }
        catch(error) {
            // console.log(error);
            return {
                error:`${error}`,
                request:this._request_JSON(request),
            };
        }
    }

    // Send an HTTP POST request, with Fetch, to create a user in Go Rest.
    //
    // -   If the request succeeds, remove the user from Go Rest, by sending an
    //     HTTP DELETE request.
    // -   If the request fails because there is already a user with the same
    //     email address, delete that user and try again.
    // -   If the request fails for any other reason, return a failure.
    //
    // This method has the same return style as the `_fetch_JSON` method.
    async _fetch_post_delete(request) {
        const userDetails = {
            name: 'Andy Warhol',
            email: 'andy@example.com',
            gender: 'Male',
            status: 'Inactive'
        };

        const userBlob = new Blob(
            [JSON.stringify(userDetails, null, 2)],
            {type : 'application/json'}
        );
        // console.log('posting', userDetails);

        const firstRequest = new Request(request, {body: userBlob});
        let response = await this._fetch_JSON(firstRequest);
        // console.log(response);

        if (response.body.code === 422) {
            // 422 is returned for anything invalid, including duplicate email
            // address. For now, assume a duplicate email address is the problem
            // and delete any matches.
            const matchResponse = await this._delete_matches(
                request, userDetails);
            if (matchResponse.error !== undefined) {
                return matchResponse;
            }

            // Try again.
            const secondRequest = new Request(request, {body: userBlob});
            response = await this._fetch_JSON(secondRequest);
        }

        if (response.body.code < 200 || response.body.code >= 300) {
            return {error: response, request: this._request_JSON(firstRequest)};
        }

        if (this._dontDelete) {
            return response;
        }

        // User entry was created OK. Delete it so that the email address isn't
        // in use and the create can be run again.
        const deleteResponse = await this._delete_id(
            request, response.body.data.id);
        if (deleteResponse.error === undefined) {
            // Delete is OK, so everything is OK. Note the deletion and return
            // the response to the POST command.
            response.deleted = "after";
            return response;
        }

        // Delete failed. Return the failure response.
        return deleteResponse;
    }

    // Delete every Go Rest user with a specified email address.
    //
    // This method uses the paging feature of the Go Rest API. Go Rest doesn't
    // seem to support querying for email address, so the code here retrieves
    // all the users, page by page. When it finds a matching user, it sends a
    // delete command and then starts again.
    //
    // This method has the same return style as the `_fetch_JSON` method.
    async _delete_matches(
        request, userDetails, duplicates=undefined, startPage=1
    ) {
        if (duplicates === undefined) {
            duplicates = [];
        }

        // The standard API doesn't seem to facilitate:
        //
        // -   Copying a Request but changing the url.
        // -   Filtering out one key from an object.
        //
        // Code here creates a new request from parts of the supplied request,
        // which will be a POST.
        const pageURI = new URL(request.url);
        pageURI.searchParams.set('page', startPage);
        const getRequest = new Request(pageURI, {
            headers: request.headers, cache: request.cache
        });
        // console.log(this._request_JSON(getRequest));
        
        const pageResponse = await this._fetch_JSON(getRequest);
        if (pageResponse.error !== undefined) {
            return pageResponse;
        }
        // console.log('match page', startPage, pageResponse.body);

        if (startPage > pageResponse.body.meta.pagination.pages) {
            return {deleted:duplicates};
        }

        let deleteNow = null;
        for(const user of pageResponse.body.data) {
            // console.log(user.email);
            if (user.email === userDetails.email) {
                deleteNow = `${user.id}`;
                break;
            }
        }
        this._transcribe({
            deleting:userDetails.email,
            page:startPage,
            found:deleteNow !== null 
        });

        if (deleteNow !== null) {
            // console.log('Deleting', startPage, deleteNow);
            const deleteResponse = await this._delete_id(request, deleteNow);
            // console.log(deleteResponse);
            if (deleteResponse.error !== undefined) {
                return deleteResponse;
            }
    
            duplicates.push(deleteNow);
            startPage = 0;
        }

        return this._delete_matches(
            request, userDetails, duplicates, startPage + 1);
    }

    // Delete the specified Go Rest user.
    //
    // This method has the same return style as the `_fetch_JSON` method.
    async _delete_id(request, userIdentifier) {
        const deleteURI = new URL(request.url);
        deleteURI.pathname = [
            ...deleteURI.pathname.split("/"), userIdentifier
        ].join("/");
        const deleteRequest = new Request(deleteURI, {
            headers: request.headers, cache: request.cache, method:"DELETE"
        });
        return await this._fetch_JSON(deleteRequest);
    }
}
Headless.apis = {
    'star-wars': {
        protocol: "https",
        hostname: "swapi.dev",
        path: ["api"],
        headers: {}
    },
    'go-rest': {
        protocol: "https",
        hostname: "gorest.co.in",
        path: ["public-api"],
        headers: {'Content-Type': 'application/json'}
    }
};

export default function(bridge) {
    new Headless(bridge);
    return null;
}
