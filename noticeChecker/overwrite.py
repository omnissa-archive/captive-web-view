# Copyright 2023 Omnissa, LLC.
# SPDX-License-Identifier: BSD-2-Clause

# Run with Python 3.9 or later.
"""File in the noticeChecker module."""
#
# Standard library imports, in alphabetic order.
#
# Sequence comparison module.
# https://docs.python.org/3/library/difflib.html#difflib.context_diff
from difflib import context_diff
#
# Module for file and directory handling.
# https://docs.python.org/3.5/library/shutil.html
import shutil

class Overwrite:

    def __init__(self, automaticResponse=None):
        self._automaticResponse = automaticResponse
    
    def prompt(self, originalPath, editedPath):
        if self._automaticResponse is not None:
            if self._automaticResponse: shutil.copy(editedPath, originalPath)
            return self._automaticResponse

        with (
            originalPath.open('r') as originalFile,
            editedPath.open('r') as editedFile
        ):
            diff = "".join(context_diff(
                originalFile.readlines(), editedFile.readlines(),
                fromfile=str(originalPath), tofile="Edited"
            ))

        print()
        if diff.strip() == "": #return False
            raise RuntimeError("Editor made no changes.", originalPath)
        print(diff)

        while True:
            response = input('    Overwrite? (Y/y*/n/n*/?)').lower()
            if response == "" or response.startswith("y"):
                print('Overwriting.')
                shutil.copy(editedPath, originalPath)
                if response.endswith("*"):
                    self._automaticResponse = True
                return True
            elif response.startswith("n"):
                print('Keeping')
                if response.endswith("*"):
                    self._automaticResponse = False
                return False
            elif response == "?":
                print(diff)
                print()
                print("y to overwrite, the default.")
                print("n to keep and not overwrite.")
                print("Append * to make that response to all future prompts.")
                print("Ctrl-c to quit.")
                print()
            else:
                print(
                    f'Unrecognised "{response}". Ctrl-C to quit or ? for help.')
