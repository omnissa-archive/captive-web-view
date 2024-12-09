# Copyright 2023 Omnissa, LLC.
# SPDX-License-Identifier: BSD-2-Clause

# Run with Python 3.9 or later.
"""File in the noticeChecker module."""
#
# Local imports
#
from noticeChecker.path_matcher import matches_transcript

def path_matcher_tests():
    for expected, *parameters in (
        (True, 'a/b/c', 'a/b/c'),
        (False, 'b/c', 'a/b/c'),
        (False, 'b/c', 'a/**/b/c'),
        (True, 'a/b/c/d/e.txt', 'd/e.*'),
        (True, 'b/c', '**/b/c'),
        (True, 'b/c', '**/**/b/c'),
        (False, 'a/b/c/d/e.txt', '/d/e.*'),
        (True, 'a/b/c/d/e.txt', '**/d/e.*'),
        (True, 'a/b/c/d/e.txt', 'a/b/**/e.*'),
        (True, 'a/b/c/d/e.txt', 'a/**/**/e.*'),
        (True, 'a/b/c/d/e.txt', '**/d/**/e.*'),
        (True, 'a/b/c/d/e.txt', 'a/**/d/**/e.*')
    ):
        matched, transcript = matches_transcript(*parameters)
        print("Pass" if matched == expected else "Fail", matched, parameters)
        for line in transcript:
            print("    " + line)
