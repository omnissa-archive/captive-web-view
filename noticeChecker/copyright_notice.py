# Copyright 2023 Omnissa, LLC.
# SPDX-License-Identifier: BSD-2-Clause

# Run with Python 3.9 or later.
"""File in the noticeChecker module."""
#
# Uses the following recent Python features.
# -   Python 3.7 subprocess text output and capture_output.
#
# Standard library imports, in alphabetic order.
#
# Date module.
# https://docs.python.org/3/library/datetime.html
import datetime
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Regular expressions module.
# https://docs.python.org/3/library/re.html
import re
#
# Temporary file module.
# https://docs.python.org/3/library/tempfile.html
from tempfile import NamedTemporaryFile
#
# Module for simple immutable objects with type specification.
# https://docs.python.org/3/library/typing.html#typing.NamedTuple
from typing import NamedTuple

# Regular expression for a copyright notice, with these capture groups.
#
# -   style, the part before the year like "Copyright" or "Copyright (c)".
#
# -   year, one to four year digits.
#
# -   suffix, the part after the year which could be the owner like
#     "Omnissa, LLC."
#
# Use it without anchoring to match ignoring and comment leaders for example.
copyrightYearRE = re.compile(
    r'''(?P<style>copyright.*)\s+     # Match up to whitespace preceding year.
        (?P<year>\d{1,4})\s+          # Match up to whitespace after year.
        (?P<suffix>(.(?=.*\S.*))*\S?) # Match multiply any character followed
                                      # by at least one non-whitespace. Then
                                      # match one optional non-whitespace in
                                      # case it's the end of the line.
        \s*$                          # Match any whitespace at the end of the
                                      # line.
    '''
    , re.IGNORECASE | re.VERBOSE
)

class DiscoveredNotice(NamedTuple):
    path: Path
    lineIndex: int
    match: re.Match
    style: str
    year: int
    suffix: str

    @classmethod
    def from_path(cls, path):
        style = None
        year = None
        suffix = None
        match = None
        matchedIndex = None
        with path.open('r') as file:
            for index, line in enumerate(file):
                match = copyrightYearRE.search(line)
                if match:
                    matchedIndex = index
                    break
        
        return cls(path, None, None, None, None, None
        ) if matchedIndex is None else cls(
            path, matchedIndex, match , match['style'], int(match['year']), match['suffix']
        )

    def rewrite_year(self, toYear=None):
        if toYear is None:
            toYear = datetime.datetime.now().year
        with NamedTemporaryFile(
            mode='wt', delete=False,
            prefix=self.path.stem + '_' , suffix=self.path.suffix
        ) as editedFile, self.path.open('rt') as originalFile:
            for index, line in enumerate(originalFile):
                if index == self.lineIndex:
                    editedFile.write(line[:self.match.start('year')])
                    editedFile.write(str(toYear))
                    editedFile.write(line[self.match.end('year'):])
                else:
                    editedFile.write(line)
            return Path(editedFile.name)
