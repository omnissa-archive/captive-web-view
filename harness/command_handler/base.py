# Copyright 2023 Omnissa, LLC.  
# SPDX-License-Identifier: BSD-2-Clause
"""\
Captive Web View python harness command handler base class and JSON handler.

Import and use it like the ../../captivityHarness/__main__.py server does."""
# Standard library imports, in alphabetic order.
#
# JSON module.
# https://docs.python.org/3/library/json.html
import json
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path

class CommandHandler:

    @staticmethod
    def parseCommandObject(commandObject):
        try:
            command = commandObject['command']
        except KeyError:
            command = None

        try:
            parameters = commandObject['parameters']
        except KeyError:
            parameters = None
        
        return command, parameters

    def __call__(self, commandObject, httpHandler):
        return None

class JSONFileCommandHandler(CommandHandler):

    def __init__(self, pathSpecifier=None):
        path = (
            Path() if pathSpecifier is None else Path(pathSpecifier)).resolve()
        self._path = path.parent.resolve() if path.is_file() else path
        super().__init__()

    # Override.
    def __call__(self, commandObject, httpHandler):
        command, _ = self.parseCommandObject(commandObject)

        if command is None:
            return None

        commandPath = Path(self._path, command).with_suffix(".json").resolve()
        if commandPath.exists():
            httpHandler.log_message(
                "%s", f'Loading response from "{commandPath}".')
            with commandPath.open() as file:
                return json.load(file)

        httpHandler.log_message("%s", f'No response object "{commandPath}".')
        return None
