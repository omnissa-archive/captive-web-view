# Run with Python 3
# Copyright 2022 Omnissa, LLC.  
# SPDX-License-Identifier: BSD-2-Clause
"""\
HTTP server that can be used as a back end to Captive Web View applications.

The server is based around a Python3 Simple HTTP Server extended to pick files
from one of a number of directories.

The server will change directory to the common parent of all directories
specified."""
#
# Standard library imports, in alphabetic order.
#
# Module for command line switches.
# Tutorial: https://docs.python.org/3/howto/argparse.html
# Reference: https://docs.python.org/3/library/argparse.html
import argparse
#
# Module for HTTP server
# https://docs.python.org/3/library/http.server.html
from http.server import HTTPServer, SimpleHTTPRequestHandler
#
# JSON module.
# https://docs.python.org/3/library/json.html
import json
#
# Module for changing the current directory.
#  https://docs.python.org/3/library/os.html#os.chdir
from os import chdir
#
# File path module.
# https://docs.python.org/3/library/os.path.html
import os.path
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Module to create an HTTP server that spawns a thread for each request.
# https://docs.python.org/3/library/socketserver.html#module-socketserver
# The ThreadingMixIn is needed because of an apparent defect in Python, see:
# https://github.com/Microsoft/WSL/issues/1906
# https://bugs.python.org/issue31639
# The defect is fixed in 3.7 Python.
# TOTH: https://github.com/sjjhsjjh/blender-driver/blob/master/blender_driver/application/http.py#L45
from socketserver import ThreadingMixIn
#
# Module for the operating system interface.
# https://docs.python.org/3/library/sys.html
from sys import exit, stderr
#
# Module for text dedentation.
# Only used for --help description.
# https://docs.python.org/3/library/textwrap.html
import textwrap

class Server(ThreadingMixIn, HTTPServer):
    @property
    def directories(self):
        return self._directories
    @directories.setter
    def directories(self, directories):
        self._directories = tuple(directories)
    
    @property
    def relativePaths(self):
        return self._relativePaths
    
    def path_for_file(self, filename):
        filename = os.path.basename(filename)
        if filename == "":
            filename = "index.html"
        for index, directory in enumerate(self.directories):
            if directory.joinpath(filename).is_file():
                return self.relativePaths[index].joinpath(filename)
        raise ValueError('File "{}" not found.'.format(filename))
    
    def handle_command(self, commandObject, httpHandler):
        raise NotImplementedError(
            "Server method `handle_command` must be set by Main subclass.")

    @property
    def start_message(self):
        """Message suitable for logging when the server is started."""

        def directory_lines(width=80, indent=2):
            # This array accumulates diagnostic logs. It is yield'd after
            # everything, unless the final yield is commented out.
            transcript = ["\n"]
            for directory in self.directories:
                first = True
                lineLen = 0
                for index, leg in enumerate(directory.parts):
                    if leg == os.path.sep and index == 0:
                        continue
                    append = ''.join(("" if index == 0 else os.path.sep, leg))
                    appendLen = len(append)
                    while True:
                        lineStart = False
                        transcript.extend('{:2d} {:2d} "{}"\n'.format(
                            lineLen, appendLen, append))
                        if lineLen == 0:
                            line = "{:<{indent}}".format(
                                ">" if first else "", indent=indent)
                            lineLen += len(line)
                            yield "\n"
                            yield line
                            lineStart = True
                        if lineLen + appendLen > width:
                            if lineStart:
                                yield append
                            first = False
                            lineLen = 0
                            if lineStart:
                                break
                        else:
                            lineLen += appendLen
                            yield append
                            break
            # Uncomment the following line to get diagnostic logs.
            # yield "".join(transcript)

        host, port = self.server_address[0:2] # Items at index zero and one.
        serverURL = "".join((
            'http://', 'localhost' if host == '127.0.0.1' else host, ':',
            str(int(port))
        ))
        #
        # Following code generates URL strings for HTML files under the first
        # directory that have an initial capital letter.
        htmlFiles = "\n".join(tuple(
            serverURL + str(htmlFile)[len(str(self.directories[0])):]
            for htmlFile in Path(self.directories[0]).glob("**/*.html")
            if htmlFile.name[0].isupper()
        ))
        
        #
        # Get the actual port number and server address. The port number could
        # be different, if zero was specified.
        return 'Starting HTTP server at {} for:{}\ncd {}\n{}'.format(
            serverURL , "".join(tuple(directory_lines()))
            , os.path.commonpath(self.directories), htmlFiles
        )
    
    def serve_forever(self):
        chdir(os.path.commonpath(self.directories))
        fromDir = Path.cwd()
        self._relativePaths = tuple(
            directory.relative_to(fromDir) for directory in self.directories)
        return super().serve_forever()

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        responsePath = None
        
        # Check for resources that are allowed to be requested from root. Chrome
        # seems to request everything other than the favicon with a path though.
        
        try:
            parted = self.path.rpartition("/")
            
            if parted[0] == "" and (parted[1] == "/" or parted[1] == ""):
                self.log_message("%s", 'Root resource "{}".'.format(self.path))
                responsePath = self.server.path_for_file(self.path)
        except ValueError as error:
            self.send_error(404, str(error))
            return

        # Check for other resources in allowed directories.
        directoryIndex = None
        if responsePath is None:
            effectivePath = (
                self.path[1:] if self.path.startswith("/") else self.path)
            for index, prefix in enumerate(self.server.relativePaths):
                if effectivePath.startswith(str(prefix)):
                    directoryIndex = index
                    break
        
            if directoryIndex is None:
                self.send_error(403)
                return
            
            # By now, it's determined that the path in the request is one that
            # is allowed by the server. It might have been requested from a
            # resource in one directory but be in another. The path_for_file()
            # method takes care of that.
            try:
                responsePath = self.server.path_for_file(self.path)
            except ValueError as error:
                self.send_error(404, str(error))
                return
        
        self.log_message("%s", 'Response path "{}" "{}" {}.'.format(
            self.path, responsePath, directoryIndex))
        if responsePath is not None:
            self.path = str(responsePath)
        super().do_GET()
    
    def _send_object(self, responseObject):
        responseBytes = json.dumps(responseObject).encode()
        self.log_message("%s", 'Response object {} {}.'.format(
            responseObject, responseBytes))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(responseBytes)
    
    def do_POST(self):
        # TOTH: https://github.com/sjjhsjjh/blender-driver/blob/master/blender_driver/application/http.py#L263
        contentLengthHeader = self.headers.get('Content-Length')
        contentLength = (
            0 if contentLengthHeader is None else int(contentLengthHeader))
        contentJSON = (
            self.rfile.read(contentLength).decode('utf-8') if contentLength > 0
            else None)
        content = None if contentJSON is None else json.loads(contentJSON)

        self.log_message("%s", "POST object {}.".format(
            json.dumps(content, indent=2)))
        
        if content is None:
            self.send_error(400)
        else:
            try:
                response = self.server.handle_command(content, self)
                if response is not None:
                    self._send_object(response)
            except:
                self.send_error(501)
                raise
        
        # self.path is ignored.

class Main:
    def __init__(self, prog, description, argv):
        argumentParser = argparse.ArgumentParser(
            prog=prog,
            description=textwrap.dedent(
                __doc__ if description is None else description),
            formatter_class=argparse.RawDescriptionHelpFormatter
        )
        argumentParser.add_argument(
            '-p', '--port', type=int, default=8001, help=
            'Port number. Default: 8001.')
        argumentParser.add_argument(
            dest='directories', metavar='directory', type=str, nargs='*', help=
            'Directory from which to server web content.')

        self.arguments = argumentParser.parse_args(argv[1:])
        self.server = Server(('localhost', self.arguments.port), Handler)
        self.server.handle_command = self.handle_command

    def server_directories(self):
        for directory in self.arguments.directories:
            yield Path(directory).resolve()
        yield Path(__file__).resolve().parents[1].joinpath(
            'Sources', 'CaptiveWebView', 'Resources', 'library')

    def command_handlers(self):
        # No command handlers by default. Yield from an empty tuple to make this
        # be a generator function.
        yield from tuple()
        return

    def __call__(self):
        self.server.directories = tuple(self.server_directories())
        for directory in self.server.directories:
            if not directory.is_dir():
                raise ValueError(f'Not a directory "{directory}".')
        self._commandHandlers = tuple(self.command_handlers())
        print(self.server.start_message)
        self.server.serve_forever()

    def handle_command(self, commandObject, httpHandler):
        response = None
        for handle in self._commandHandlers:
            response = handle(commandObject, httpHandler)
            if response is not None:
                break

        # Following code would send a redirect to the client. Unfortunately,
        # that causes the client to redirect the POST, instead of it loading
        # another page instead.
        #
        # if "load" in commandObject:
        #     responseBytes = json.dumps({}).encode()
        #     httpHandler.log_message("%s", 'Redirect {}.'.format(
        #         responseBytes))
        #     httpHandler.send_response(303, json.dumps(commandObject))
        #     httpHandler.send_header('Location', commandObject["load"])
        #     httpHandler.end_headers()
        #     httpHandler.wfile.write(responseBytes)
        #     return None

        # TOTH for ** syntax: https://stackoverflow.com/a/26853961
        if response is None:
            response = { **commandObject, "failed": f"Unhandled." }

        if 'failed' not in response and 'confirm' not in response:
            response['confirm'] = " ".join((
                self.__class__.__name__,
                httpHandler.server_version,
                httpHandler.sys_version))

        return response

if __name__ == '__main__':
    stderr.write(
        "This file can only be run as a module, like `python -m harness`\n")
    exit(1)
