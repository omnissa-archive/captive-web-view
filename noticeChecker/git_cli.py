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
# Module for spawning a process to run a command.
# https://docs.python.org/3/library/subprocess.html
import subprocess

def git_modified_date(path):
    # Get the date of the last commit.
    with subprocess.Popen(
        (
            'git', 'log', '--follow', '--diff-filter=r', '--max-count=1'
            , r'--pretty=format:%cd', r'--date=format:%Y %m %d', str(path)
            # TOTH --follow and --diff-filter.
            # https://stackoverflow.com/a/76093515/7657675
        ), stdout=subprocess.PIPE, text=True
    ) as gitProcess:
        with gitProcess.stdout as gitOutput:
            # The line will be year, month, day separated by spaces. Put
            # them into a tuple, then spread the tuple into the date()
            # constructor.
            components = tuple(
                int(piece) for piece in gitOutput.readline().split())
        gitProcess.wait()
        return datetime.date(*components)

def git_ls_files(paths=None):
    # See: https://git-scm.com/docs/git-ls-files  
    # -z switch specifies null-terminators instead of newlines, and verbatim
    # file names for unprintable values.
    with subprocess.Popen(
        ('git', 'ls-files', '-z', '--', *paths)
        , stdout=subprocess.PIPE, text=True
    ) as gitProcess:
        with gitProcess.stdout as gitOutput:
            name = []
            while True:
                readChar = gitOutput.read(1)
                if readChar == "": return
                if readChar == "\x00":
                    yield Path(''.join(name))
                    name = []
                else:
                    name.append(readChar)

def git_is_different(path):
    run = subprocess.run(
        ('git', 'diff', '--name-only', '--exit-code', path)
        , stdout=subprocess.DEVNULL, text=True
    )
    # TOTH those command line options.
    # https://stackoverflow.com/a/50117376/7657675
    return run.returncode != 0

# The git_pathspec() function, below, was intended to generate a Git path
# specification from a list of paths and a list of patterns to ignore. Jim
# couldn't get it to work reliably. For example, this command produced no
# output.
#
#     git ls-files \
#          forAndroid/CaptiveCrypto/src/main/res/values \
#          ':!:forAndroid/**/ic_launcher*.xml'
#
# So ignore patterns are instead handled down stream from the git ls-files, in
# the NoticeChecker scanning function.
#
#
# Module for operating system interfaces. Only used to get the path separator.
# https://docs.python.org/3/library/os.html#os.sep
# from os import sep, altsep
#
# def git_pathspec(paths=None, ignoringPatterns=None):
#     # Create tuples for the parameters to support generators.
#     paths = tuple() if paths is None else tuple(paths)
#     ignoringPatterns = (
#         tuple() if ignoringPatterns is None else tuple(ignoringPatterns))
#     if len(ignoringPatterns) > 0:
#         if len(paths) == 0:
#             # If only ignore patterns have been specified, set paths to be a
#             # single-element tuple that specifies the current directory.
#             paths = ('.',)
#         for pattern in ignoringPatterns:
#             # TOTH applying multiple exclude patterns to a Git pathspec.
#             # https://stackoverflow.com/questions/36753573/how-do-i-exclude-files-from-git-ls-files#comment93098741_53083343
#             # Git pathspec with a trailing / seems to prevent ignore patterns
#             # from matching. Strip the trailing separator here. To be on the
#             # safe side, use sep and altsep from the os module. The sep value is
#             # never None but altsep can be, on macOS for example.
#             for path in paths:
#                 yield path.rstrip(sep if altsep is None else sep + altsep)
#             yield ':!:' + pattern
#     else:
#         yield from paths
