# Run with Python 3
# Copyright 2022 Omnissa, LLC.  
# SPDX-License-Identifier: BSD-2-Clause
"""\
HTTP server that can be used as a back end for the Captivity application during
development."""

# To get the command line usage, run it like this.
#
#     cd /path/where/you/cloned/captive-web-view/
#     python3 -m captivityHarness --help

#
# Standard library imports, in alphabetic order.
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Module for the operating system interface.
# https://docs.python.org/3/library/sys.html
from sys import argv, exit
#
# Local imports.
#
# Harness HTTP server base class.
from harness.server import Main
#
# Command handlers.
from harness.command_handler.base import JSONFileCommandHandler
from harness.command_handler.fetch import FetchCommandHandler

class Captivity(Main):
    # Override.
    def command_handlers(self):
        yield JSONFileCommandHandler(__file__)
        yield FetchCommandHandler()
        yield from super().command_handlers()

    # Override.
    def server_directories(self):
        # Add path with the Captivity HTML/CSS/JavaScript files.
        yield Path(__file__).parents[1].joinpath(
            'WebResources', 'Captivity', 'UserInterface')
        yield from super().server_directories()

exit(Captivity("python3 -m captivityHarness", __doc__, argv)())
