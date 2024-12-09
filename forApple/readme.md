# Captive Web View for Apple
Captive Web View is compatible with iOS, iPadOS, Catalyst, and native macOS. For
an introduction to Captive Web View, see the [parent directory](..) readme file.

# Usage
First check that you have a compatible development environment, see the
following table.

Software | Instructions last tested | Built
---------|--------------------------|-------
Xcode    | 14.0                     | 14.0

The instructions below describe how to use Captive Web View in your app. For
more detailed information on how it works, see the
[reference documentation](../documentation/reference.md) file.

# Sample Applications
The following sample applications can be used as a starting point for your own
application based on Captive Web View.

-   [Skeleton](Skeleton) is an empty application for iOS, iPadOS, or Catalyst.
-   [MacSkeleton](MacSkeleton) is an empty application for native macOS.

Those applications include the Captive Web View as a remote package dependency.

The other sample applications in this repository are in an Xcode workspace with
the  Captive Web View code and include it as a local package dependency. They
demonstrate its use but aren't so suitable as a starting point.

The difference between remote and local package dependencies can be seen in
Xcode.

-   Remote package dependencies appear in the Project editor, on the Package
    Dependencies tab, and also appear in the Target editor, on the General tab,
    in the Frameworks, Libraries, and Embedded Content section.
-   Local package dependencies only appear in the Target editor, in the same
    place as remote dependencies.

You can copy either Skeleton app, or start with a new app, or change an existing
app.

# Add the framework
The Captive Web View framework is available as a Swift Package. Use the Swift
Package Manager built into Xcode to add the framework to an Xcode project as a
package dependency.

See the Skeleton application Xcode projects as examples, or proceed as follows.

1.  In Xcode, navigate to File, Add Packages...

2.  If prompted, when working with an Xcode workspace, select the Xcode project
    requiring the framework.

3.  Enter the package repository URL:
    `https://github.com/omnissa-archive/captive-web-view.git`

4.  Enter `main` as the branch.

This completes adding the Captive Web View framework.

# Integrate into a View Controller
After adding the Captive Web View framework, see above, you can integrate it
into an iOS view controller. The view controller will then have a web view as
its user interface. The web view will be instead of a native user interface
built with a storyboard and UIKit for example.

If the view controller that you integrate is the only view controller in the
application, then the whole application user interface will be in a web view.
This isn't the only integration option. You can instead apply Captive Web View
to a WKWebView instance that is one element in a native user interface, or to a
WKWebView instance that is hidden. See the [Headless](Headless) application for
sample code, and see the [headless documentation](../documentation/headless.md)
file for notes.

To integrate into a view controller, follow these instructions.

1.  Change the ViewController class to be based on a Captive Web View class.

    Open the ViewController.swift file in Xcode and make the following changes.

    1. Import the module, for example by adding a line like:

            import CaptiveWebView

    2. Change the ViewController to a subclass of the default view controller
        class in the module, for example by changing the declaration to:

            class ViewController: CaptiveWebView.DefaultViewController {
            ...
            }

    The default view controller is a higher-level interface that simplifies
    implementation of a Captive Web View application.

    You can delete the viewDidLoad method from your ViewController class.

2.  Set the name of the HTML file to load in your view controller.

    Choose a name, like `Main.html` and then do **either** of the following, but
    not both.

    -   Open the ViewController.swift file in Xcode and override the computed
        value for the `mainHTML` property, for example as follows.

            override var mainHTML: String { return "Main.html" }
    
    -   Rename the ViewController class to MainViewController.

        The Xcode IDE facilitates renaming a class as a type of refactoring.
        **Be careful** you don't change anything in the Captive Web View
        framework. For example, unselect those incidences in the Xcode rename
        confirmation screen.

        Xcode mightn't actually change the name of the ViewController.swift
        file, even if you select to do so. If that happens, exit Xcode and
        rename the file by hand.
    
    What's happening behind the scenes:  
    The Captive Web View framework includes a ViewController base class, one
    level below the DefaultViewController. The base class has the code that
    loads the web content into a WKWebView, starting with an HTML file. By
    default, it generates the HTML file name from the ViewController subclass
    name. Generation consists of deleting the suffix "ViewController". So, you
    can either rename your ViewController class or override the default
    behaviour.

3.  Create the HTML file.

    If you have already created a corresponding Android application that will
    have the same user interface, then skip this step.

    It can be tidy to have a dedicated sub-directory, for example named
    `UserInterface`, just for your user interface web resources. This also
    facilitates sharing the files with an Android application if you create one
    later. Create the sub-directory by hand, under the application project
    directory.

    In a text editor, or in Xcode, create a file in the sub-directory. In the
    preceding step, `Main.html` was the suggested name. Note the initial
    capital.

    Copy and paste the following HTML code into the file, or copy the
    [UserInterface/Main.html](../WebResources/Skeleton/UserInterface/Main.html)
    file from the Skeleton application.

        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {font-family: sans-serif;}
            </style>
        </head>
        <body
        ><script src="captivewebview.js"></script
        ><script>
            CaptiveWebView.whenLoaded("main.js");
        </script
        ><h1 id="loading">Loading ...</h1
        ></body>
        </html>

    There are two script tags, one for the Captive Web View bridge
    initialisation, `captivewebview.js`, the other for your code `main.js` in
    this example. The HTML is written in a whitespace elimination style, i.e.
    with no space in between an end tag and the start of the next tag.

4.  Add the web resources to the application.

    If you created a UserInterface/ sub-directory in the previous step, or if
    you skipped the previous step because you already have one in an Android
    project, then add the sub-directory now. You can do this in Xcode, as
    follows.

    1. Right-click the application folder, which may be the first level under
        the application project. Then select the option to Add Files to "..."
        ... in the context menu that drops down.
    2. In the dialog that appears, highlight the user interface directory and
        select the option to Create folder references. Don't select to copy
        items.
    3. Click Add.

    The sub-directory should now appear under the application's folder. It
    should have a blue folder icon. If it doesn't, remove it and try again.

    If you expand the blue folder, you should see the contents of the directory,
    including the Main.html file if you called it that.

    Note for sharing files with an Android project:  
    Android applications are built with Gradle, in which it is easiest to have
    all files are under one umbrella directory. For this reason, you could put
    the web resource files in the Android project directory, and a have a
    reference to that directory from the Xcode project.  
    An alternative is to use a sourceSets block in the Gradle build files for
    the Android application. You can add an assets directory in the sourceSets
    block, and specify a path outside the Android app project directory. This
    approach is used by the Captive Web View sample applications. For example,
    real web resource files for the Skeleton app are in the directory:  
    `captive-web-view/WebResources/Skeleton/UserInterface/`  
    A reference to that directory appears in the Xcode project at
    Skeleton/UserInterface, and in the Skeleton for Android build.gradle file.

5.  Create the JavaScript file.

    If you have already created a corresponding Android application that will
    have the same user interface, then skip this step.

    In a text editor, or in Xcode, create a new file in the same sub-directory
    as the HTML file you created earlier. The boilerplate HTML uses `main.js` as
    the name.

    Copy and paste the following JavaScript code into the file, or copy the
    [UserInterface/main.js](../WebResources/Skeleton/UserInterface/main.js)
    file from the Skeleton application.

        class Main {
            constructor(bridge) {
                const loading = document.getElementById('loading');

                this._transcript = document.createElement('div');
                document.body.append(this._transcript);

                bridge.receiveObjectCallback = command => {
                    this._transcribe(command);
                    return Object.assign(command, {"confirm": "Main"});
                };

                loading.firstChild.textContent = "Application Name";
                // ToDo: Change to the name of your application.

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

6.  Run the application.

    At this point you should be able to build and run the application.

    The user interface will look like this:

    # Application Name

        {
            "failed": "Unknown command \"ready\"",
            "command": "ready"
        }

    This could also be a good opportunity to try out the Safari developer tools.
    
    -   Do an Internet search for "Safari developer tools" for basic information
        and instructions.

    -   You have to do something extra to enable the Safari developer tools to
        inspect the WKWebView in your application running on a device, as
        follows.

        1.  On the device, open Settings and navigate to Safari, Advanced.
        2.  Set the following both on: JavaScript, Web Inspector.

        You might have to restart Safari on your desktop, and on your device,
        and restart Xcode and re-install your application for the change to take
        effect.

    -   If you are using a beta version of iOS, you might have to use the Safari
        Technology Preview version.

        Download is available here, at time of writing:  
        [https://developer.apple.com/safari/download/](https://developer.apple.com/safari/download/)
        
        TOTH:  
        [https://developer.apple.com/forums/thread/96217?answerId=303426022#303426022](https://developer.apple.com/forums/thread/96217?answerId=303426022#303426022)

7.  Add the Swift end of the command handler.

    When you ran your application in the previous step, there was a failure
    message. This is because the JavaScript end sent a command, "ready", that
    the native Swift end didn't recognise. Now add a handler that recognises
    that command.

    1.  Open your view controller .swift file in Xcode.
    2.  In your view controller class, declare an override for the
        response:to:in: method.
    3.  Add a method body that returns an empty dictionary in response to the
        "ready" command, or delegates to its base class for other commands.
    
    The new method looks like this:

        override func response(
            to command: String,
            in commandDictionary: Dictionary<String, Any>
            ) throws -> Dictionary<String, Any>
        {
            switch command {
            case "ready":
                return [:]
            default:
                return try super.response(to: command, in: commandDictionary)
            }
        }

    The above code is also in the
    [MainViewController.swift](Skeleton/Skeleton/MainViewController.swift) file
    in the Skeleton application.

8. Run the application again.

    The user interface will look like this:

    # Application Name

        {
            "command": "ready",
            "confirm": "MainViewController bridge OK."
        }

     Note that there is a round trip starting with a command object in the
     JavaScript layer that becomes a dictionary in the Swift layer, then a
     response dictionary in the Swift layer that becomes an object in the
     JavaScript layer.

This concludes the initial integration. The next step could be to:

-   Add more JavaScript code that builds an HTML5 user interface, inside the web
    view. Captive Web View comes with a JavaScript module, pagebuilder, that
    facilitates building a user interface.

-   Add a native-to-JavaScript bridge, see below.

-   Remove the application storyboard, see below.

# Bridge from native to JavaScript
The view controller integration instructions, see the previous section, add a
bridge from JavaScript to the native layer. The following instructions add a
bridge in the opposite direction.

You only need the opposite bridge if you have events or interactions that start
in the native layer. You don't need this bridge just to respond to commands from
the JavaScript layer.

Proceed as follows.

1.  In the Swift code, add a call to the `sendObject()` method.

    The method can be called

    -   as `self.sendObject()` in a CaptiveWebView.DefaultViewController
        subclass.
    -   as `self.sendObject()` in a CaptiveWebView.ViewController subclass.
    -   as `CaptiveWebView.sendObject(to:)` anywhere there is access to the
        WKWebView instance.

2.  Pass the required parameters to the sendObject call:

    -   The `command` to run in the JavaScript layer, as a `Dictionary<String,
        Any>` instance.
    -   The `completionHandler` to receive the response from the JavaScript
        layer, as a `((Any?, Error?) -> Void)` closure. The handler is optional.

    If called as sendObject(to:) then also pass the WKWebView instance, as the
    first parameter.

    See the following examples.

    From the
    [MainViewController.swift](Skeleton/Skeleton/MainViewController.swift) file
    in the Skeleton application:

        self.sendObject(["fireDate":"fireDateValueGoesHere"]) {
            (result:Any?, error:Error?) in
            os_log("sendObject result: %@, error: %@",
                    String(describing: result), String(describing: error)
        )
    
    In the above example, the command is fireDate and the completion handler
    logs the response, using the native os_log function.

    From the [ViewController.swift](Headless/Headless/ViewController.swift) file
    in the Headless application:

        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"star-wars",
                "path":["planets", String(describing: numericParameter)]
            ], self.sendObjectCallback)

    In the above example, the command has two parameters, api and path, and the
    completion handler is the sendObjectCallback method (not shown).

3.  In the JavaScript code, in the `bridge.receiveObjectCallback` handle the
    command sent from new Swift code added in the preceding instructions.

    For example, the
    [UserInterface/main.js](../WebResources/Skeleton/UserInterface/main.js) file
    in the Skeleton application handles all commands with the following code.

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "Main"});
        };

    This logs the command to the web view user interface, in the `_transcribe`
    method (not shown), and then returns a copy of the command with an added
    `confirm` property.

    For a more complex example, see the
    [headless.js](../WebResources/Headless/WebResources/headless.js) file from
    the Headless application. Look for the `_command` method, which uses the
    standard Fetch API to run various commands on a couple of web services.

This concludes adding a native-to-JavaScript bridge.

# Remove the application storyboard
The CaptiveWebView.ViewController class instantiates a WKWebView
programmatically, and constrains it to fill the application's user interface
window. This means that it doesn't need a storyboard.

A storyboard might have been created by default in a new application. It can be
removed by proceeding as follows.

1.  Change your AppDelegate to be a subclass of the
    CaptiveWebView.ApplicationDelegate class.

    Code could be like this:

        @UIApplicationMain
        class AppDelegate: CaptiveWebView.ApplicationDelegate {
            // ...
        }

2.  In the didFinishLaunchingWithOptions, call the `self.launch` method and pass
    your main ViewController class as a parameter.

    Code could be like this:

        self.launch(MainViewController.self)

    For an example, see the
    [AppDelegate.swift](Skeleton/Skeleton/AppDelegate.swift) file in the
    Skeleton application.

3.  Remove the scene session life cycle methods from your AppDelegate class, if
    necessary.

    Xcode might have added them by default, as follows.

        // MARK: UISceneSession Lifecycle

        func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
            ...
        }

        func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
            ...
        }
    
    Delete the MARK and the methods.

3.  Remove the UIMainStoryboard setting from the Info.plist file.

4.  Remove the Main.storyboard file from the project.

This concludes removing the application storyboard.

# Troubleshooting
An error like this sometimes appears in the log.

>   WebProcessProxy::didFinishLaunching: Invalid connection identifier (web
>   process failed to launch)

That could be due to a missing entitlement
`com.apple.security.files.user-selected.read-only` Outgoing Network Connections.

Another symptom of the same condition is that the web view doesn't load any
content. Debugging may show that the custom scheme handler isn't invoked when
web view content is loaded. The entitlement seems to be required for the web
view to load any content, even local files from your app resources.

To resolve the issue, add the required entitlement. TOTH
[stackoverflow.com/a/72303749/7657675](https://stackoverflow.com/a/72303749/7657675).

Legal
=====
Copyright 2023 Omnissa, LLC.  
SPDX-License-Identifier: BSD-2-Clause
