Compatibility
=============
These instructions work for the following software versions.

Software       | Version
---------------|--------------------------
Android Studio | Flamingo 2022.2.1 Patch 2

How to get the framework
==========================
1.  Download the code in the repository that contains this file.

    This project has some **case-sensitive file names**. This means that it may
    be a good idea to switch off case sensitivity in the Git configuration. See:
    [https://stackoverflow.com/a/37844763/7657675](https://stackoverflow.com/a/37844763/7657675)

2.  Open Android Studio and then as a new project, open this location:

        /wherever/you/cloned/captive-web-view/forAndroid/

3.  Execute the Gradle task: forAndroid/Tasks/publishing/publish

That should create a maven repository under the
/wherever/you/cloned/captive-web-view/m2repository/ directory.

You can then add the framework library to an application by following the
instructions in the next section.

Add the library to your Android application
===========================================
To add the library to your Android application:

-   Add the local Maven repository to the top-level build.gradle file.
-   Add an implementation to the dependencies in the application build.gradle
    file.

Project build.gradle file snippet:

    ...

    allprojects {
        repositories {
            google()
            mavenCentral()

            // Next declaration is added:
            maven {
                url uri(new File(
                    rootDir, '../relative/path/to/captive-web-view/m2repository'))
            }
            // ToDo: Change to the actual relative path.
        }
    }

    ...

Application build.gradle file snippet:

    ...

    dependencies {
        implementation fileTree(include: ['*.jar'], dir: 'libs')
        implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
        implementation 'com.android.support:appcompat-v7:28.0.0'
        implementation 'com.android.support.constraint:constraint-layout:1.1.3'
        testImplementation 'junit:junit:4.12'
        androidTestImplementation 'com.android.support.test:runner:1.0.2'
        androidTestImplementation 'com.android.support.test.espresso:espresso-core:3.0.2'

        // Next line is added:
        implementation 'com.example.captivewebview:captivewebview:5.7'
        // ToDo: Replace 5.7 with whatever is the latest.
    }

    ...

You can now create a Captive Web View Activity.

Create an Activity
==================
To create an Activity, proceed as follows.

1.  Add a class to your application.

    Make it a Kotlin class. Don't create a layout.

    Detailed steps are:
    
    1.  In the Android Project navigator, expand the application module, then
        expand the java folder, then select the main package, i.e. the one that
        isn't a test package.
    2.  In the application menu, select File, New, Kotlin File/Class.
    3.  Type in a name, like MainActivity, and select Kind: Class.

2.  Make the class a subclass of the DefaultActivity subclass in the library.

    The code could look like this:

        class MainActivity : com.example.captivewebview.DefaultActivity() {
        }

    There will also be a `package` statement, which might have been added by the
    IDE.

    The DefaultActivity class is a higher-level interface that simplifies
    implementation of a Captive Web View application.

3.  Add some necessary Activity configurations.

    Add the following to the Android manifest XML.

        <activity
            android:name=".MainActivity"
            android:configChanges="orientation|screenSize|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    
    Change `MainActivity` to the class name of your Activity.

    Tips:

    -   The manifest can be opened for editing by navigating as follows: expand
        the application module, then the manifest folder, then double-click the
        AndroidManifest.xml file.
    
    -   The activity declaration must be inserted into the application tag. The
        IDE might have created a self-closing application tag, i.e. like the
        following.

            <application
                ... Attributes Here ... />

        To insert the activity tag, this must be changed to an open-close tag,
        like the following.

            <application
                ... Attributes Here ... >
                <activity
                    ... >
                    ...
                </activity>
            </application>

    It's maybe a good idea to invalidate the Android Studio cache and restart
    now. In Android Studio, select File, Invalidate Caches / Restart.
    
    TOTH:
    [https://stackoverflow.com/a/32721916/7657675](https://stackoverflow.com/a/32721916/7657675)

4.  Create an HTML asset file to show in the Activity.

    It can be tidy to have an asset sub-directory just for your user interface 
    HTML files.

    In Android Studio, select the application module, then select:  
    File, New, Folder, Assets Folder. Defaults are OK.

    To create a sub-directory, select the assets folder, then select:  
    File, New, Directory. Give it a name like UserInterface.

    To create the file, select the sub-directory, then select:  
    File, New, File. Give the HTML file the same name as the Activity class but
    without the "Activity" suffix. For example, if the class is MainActivity
    then Main.html would be the file name, with an initial capital.

5.  Add boilerplate HTML like this:

        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
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

6.  Create your application user interface in JavaScript.

    Your Android Studio mightn't offer JavaScript editing, depending on which 
    edition you are running. Other JS editors are available.

    Create the main.js file with the following content.

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
    
    Save it in the same location as the HTML file.

7.  Run the application.

    At this point you should be able to build and run the application.

    The user interface will look like this:

    # Application Name

        {
            "command": "ready",
            "failed": "java.lang.Exception: Unknown command \"ready\"."
        }

    This could also be a good opportunity to try out the Chrome developer tools.
    An embedded WebView in an application connected via the Android Developer
    Bridge (adb) can be inspected with the Chrome developer tools. You can start
    by opening a new tab in Chrome desktop and entering `chrome://inspect/` in
    the address bar. Do an internet search for "Chrome developer tools" for
    basic information and instructions.
    
8.  Add the Kotlin end of the command handler.

    When you ran your application in the previous step, there was a failure
    message. This is because the JavaScript end sent a command, "ready", that
    the native Kotlin end didn't recognise. Now update the handler to recognise
    that command.

    1.  Open your Activity .kt file in the Android Studio editor.
    2.  In your Activity class, declare an override for the `commandResponse`
        method.
    3.  Add a method body that returns the JSONObject with which it was invoked
        in response to the "ready" command, or delegates to its base class for
        other commands.

    The new method could look like this:

        override fun commandResponse(
            command: String?,
            jsonObject: JSONObject
        ): JSONObject {
            return when(command) {
                "ready" -> jsonObject
                else -> super.commandResponse(command, jsonObject)
            }
        }

    The above code is also in the MainActivity.kt file in the Skeleton
    application in the repository Android project.

    Android Studio may add an import statement, for JSONObject, or facilitate
    you to do that.

11. Run the application again.

    The user interface will look like this:

    # Application Name

        {
            "command": "ready",
            "confirm": "MainViewActivity bridge OK."
        }

    The `confirm` text comes from the Captive Web View library, in the
    DefaultActivityMixIn class.

    Note that there is a round trip starting with a command object in the
    JavaScript layer that becomes a JSONObject instance in the Kotlin layer,
    then a response JSONObject in the Kotlin layer that becomes an object in the
    JavaScript layer.

This concludes the initial application build. The next step could be to:

-   Add more JavaScript code that builds an HTML5 user interface, inside the web
    view.
-   Add a native-to-JavaScript bridge, see below TBD.




Appendix: Create a new Android application
==========================================
In case you want to create a new application to try out the library, proceed as
follows.

1.  Open Android Studio.
2.  In the menu, select File, New, New Project. This opens the Create New
    Project screen, in which there is a prompt to Choose your project.
3.  Select to Add No Activity and then Next. This opens the next step, which is
    to Configure your project.
4.  Type in whatever name you like. Create a new directory as the Save location.
    You can do this from the interaction that opens when you click the folder
    icon. Select Language: Kotlin. There is no need for instant apps support,
    nor for androidx artifacts.

Allow the Gradle build to finish and you have a new project.

-   You may wish to change the module name from "app". You can do this as
    follows.

    1.  Select the module in the Android Project view.
    2.  In the menu, select Refactor, Rename ...
    3.  When prompted, select to Rename module.
    4.  When prompted, type in the new name. It can't be the same as the project
        name for some reason.

Now proceed with adding the Captive Web View library.

-   The `settings.gradle` file might have a configuration to block local
    repositories. If it does then you may remove that configuration, by
    commenting it out, for example like this.

        dependencyResolutionManagement {
            // Comment out this line.
            // repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
            repositories { ... other code can stay ... }
        }
    
    If the configuration is in effect then an error like this gets generated at
    build time.

        > Build was configured to prefer settings repositories over project
        repositories but repository 'Google' was added by build file
        'build.gradle'

-   You may wish to add the following to the Android manifest file:

        <meta-data
            android:name="android.webkit.WebView.MetricsOptOut"
            android:value="true"
            />

    Reference: https://developer.android.com/guide/webapps/managing-webview#metrics

# Appendix: Source Integration
Captive Web View can instead be integrated as a sub-module from source, instead
of as a compiled library. That can be useful if you are working on the library
code on a branch for example. Make these changes to the build configuration.

In the project `build.gradle` file, remove or comment out the local Maven
declaration, like this.

    allprojects {
        repositories {
            google()
            mavenCentral()

            // maven {
            //     url uri(new File(rootDir, '../captive-web-view/m2repository'))
            // }
        }
    }

In the project `settings.gradle` file, add include statements for the Captive
Web View project and library module.

    include 'captive-web-view'
    project(':captive-web-view').projectDir = file(
        '../relative/path/to/captive-web-view/forAndroid')
    include ':captive-web-view:captivewebview'

In the app module `build.gradle` file, replace the library dependency with a
project dependency that builds from source.

    // implementation 'com.example.captivewebview:captivewebview:7.0'
    implementation project(':captive-web-view:captivewebview')

Re-synchronise Android Studio from the Gradle to finalise the changes.

Scratchpad
==========
Another section about adding the Kotlin to JS bridge goes here. To include the
following snippets.

Kotlin end, sender:

    sendObject(mapOf("blib" to 4)) {
        val jsonObject = it
    }

JavaScript end, receiver:

    this._bridge.receiveObjectCallback = command => {
        this._transcript.add(JSON.stringify(command));
        return Object.assign(command, {"confirm": "Demonstration"});
    };

net::ERR_CACHE_MISS means you don't have the Android uses internet permission.
TOTH: https://stackoverflow.com/a/35294446/7657675

How to resolve errors with the Java version, like this one.

>   Caused by: com.android.builder.errors.EvalIssueException: Android Gradle
>   plugin requires Java 11 to run. You are currently using Java 1.8.

Select the JDK from Android Studio. TOTH
[https://stackoverflow.com/a/66450524/7657675](https://stackoverflow.com/a/66450524/7657675)

Legal
=====
Copyright 2023 Omnissa, LLC.  
SPDX-License-Identifier: BSD-2-Clause
