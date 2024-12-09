# Copyright 2023 Omnissa, LLC.  
# SPDX-License-Identifier: BSD-2-Clause
# Run with Python 3
"""Script to check copyright notices.

1.  Scans the current directory for files under revision control by running git
    ls-files.
2.  Runs git diff and git log to determine the last modified date for each file.
3.  Reads each file to discover any embedded copyright notice.

Each file then has one of these states.

-   MISSING, if the file doesn't have a copyright notice.
-   INCORRECT_DATE, if the year in the copyright doesn't match the git modified
    date.
-   CORRECT, otherwise.

The script will, with user confirmation, edit in a corrected date to each file
with INCORRECT_DATE or MISSING status.

A summary of file statuses is printed.

Some file formats and names are exempt, such as binary formats and the
gradlew.bat file."""
# This file makes the directory a runnable module. To get the command line
# usage, run it like this.
#
#     cd /path/where/you/cloned/captive-web-view/
#     python3 -m noticeChecker --help

#
# Standard library imports, in alphabetic order.
# 
# Module for command line switches.
# Tutorial: https://docs.python.org/3/howto/argparse.html
# Reference: https://docs.python.org/3/library/argparse.html
import argparse
#
# Module for OO path handling. Only used to declare a Path type CLI.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Module for the operating system interface.
# https://docs.python.org/3/library/sys.html
from sys import argv, exit
#
# Module for text dedentation.
# Only used for --help description.
# https://docs.python.org/3/library/textwrap.html
import textwrap
#
# Local imports.
#
from noticeChecker.notice_checker import NoticeChecker
from noticeChecker.test_path_matcher import path_matcher_tests

class TestAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        path_matcher_tests()
        parser.error("Ran path matcher tests.")

def main(commandLine):
    # Instantiate here so that the default values can be printed in the usage.
    noticeChecker = NoticeChecker()

    argumentParser = argparse.ArgumentParser(
        prog="python3 -m noticeChecker",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(__doc__))
    argumentParser.add_argument(
        '-e', '--edit', choices=['yes', 'y', 'no', 'n', 'prompt']
        # TOTH case insensitive choice matching.
        # https://stackoverflow.com/a/27616814/7657675
        , type=str.lower, default='prompt', help=
        "yes or y to edit without user confirmation; no or n to edit nothing."
        " Default is to prompt for each file.")
    argumentParser.add_argument(
        '-s', '--summarise-first', dest='summariseFirst', action='store_true'
        , help=
        "Finish the scan and print the summary before offering any edits."
        " Default is to offer edits as soon as editable files are scanned.")
    argumentParser.add_argument(
        '--notice-template', metavar='FILE', type=Path
        , dest='noticeTemplatePath', default=noticeChecker.noticeTemplatePath
        , help=
        'Copyright notice template file. Contents are treated as a date format.'
        ' Put %%Y where the year should be inserted.'
        f' Default is "{noticeChecker.noticeTemplatePath}".')
    argumentParser.add_argument(
        '--stop-after', dest='stopAfter', type=int, default=0, help=
        'Stop after checking the specified number of files. Or specify zero'
        ' not to stop. This is a diagnostic option. Default is zero.')
    argumentParser.add_argument(
        '--ignore-from', metavar='FILE', type=Path
        , dest='noticesIgnorePath', default=noticeChecker.noticesIgnorePath
        , help=
        'File for paths to ignore. Format is like .gitignore files.'
        f' Default is "{noticeChecker.noticesIgnorePath}".')
    argumentParser.add_argument(
        '--exempt-update-names', dest='exemptUpdateNames', metavar='NAME.SUF'
        , type=str, default=noticeChecker.exemptUpdateNames, nargs='*', help=
        'Files with these names are exempt from copyright checking.'
        f' Default is {noticeChecker.exemptUpdateNames}.')
    argumentParser.add_argument(
        '--exempt-update-suffixes', dest='exemptUpdateSuffixes'
        , metavar='.SUFFIX', type=str
        , default=noticeChecker.exemptUpdateSuffixes, nargs='*', help=
        'Files with these suffixes are exempt from copyright checking.'
        f' Default is {noticeChecker.exemptUpdateSuffixes}.')
    argumentParser.add_argument(
        '--exempt-missing-suffixes', dest='exemptMissingSuffixes'
        , metavar='.SUFFIX', type=str
        , default=noticeChecker.exemptMissingSuffixes, nargs='*', help=
        "Files with these suffixes won't have a notice inserted automatically"
        " if there isn't a notice. However, if there is a notice then it will"
        " be updated automatically."
        f' Default is {noticeChecker.exemptMissingSuffixes}.')
    argumentParser.add_argument(
        '-v', '--verbose', action='store_true', help=
        "Print every file path and its notice state during the scan. Default is"
        " to print only a single state indicator character per file during the"
        " scan.")
    argumentParser.add_argument(
        '--tests', action=TestAction, nargs='?', help=
        "Run a test suite instead of checking notices.")
    argumentParser.add_argument(
        'gitPathSpecifiers', metavar="PATHSPEC", nargs="*", help="""
Append git path specifiers to the initial git ls scan. For example,
'*.storyboard' scans only .storyboard files anywhere in the hierarchy. Any Git
path specifier can be used. Look for 'pathspec' in the man page for gitglossary
for details.""")
    return argumentParser.parse_args(commandLine[1:], noticeChecker)()

exit(main(argv))
