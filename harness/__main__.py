# Run with Python 3
# Copyright 2022 Omnissa, LLC.  
# SPDX-License-Identifier: BSD-2-Clause

# This file makes harness a runnable module. To get the command line usage, run
# it like this.
#
#     cd /path/where/you/cloned/captive-web-view/
#     python3 -m harness --help

#
# Standard library imports, in alphabetic order.
#
# Module for the operating system interface.
# https://docs.python.org/3/library/sys.html
from sys import argv, stderr, exit
#
# Local imports.
#
# The HTTP server harness.
from harness import server

exit(server.Main("python3 -m harness", None, argv)())
