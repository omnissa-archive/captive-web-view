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
# Enumeration class module.
# https://docs.python.org/3/library/enum.html
import enum
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Local imports.
#
from noticeChecker.git_cli import git_ls_files
from noticeChecker.noticed_file import NoticeState, NoticedFile, str_quote
from noticeChecker.overwrite import Overwrite
from noticeChecker.notice_editor import NoticeEditor
from noticeChecker.path_matcher import PathMatcher

# General TOTH
# https://github.com/omnissa-archive/workspace-ONE-SDK-integration-samples/blob/main/IntegrationGuideForAndroid/Apps/samers.py

class Edit(enum.Enum):
    YES = True
    NO = False
    PROMPT = None

def first_or_len(paths):
    return str(paths[0]) if len(paths) == 1 else (str(len(paths)) + ".")

class NoticeChecker:

    # Properties that are set by the CLI.
    #
    @property
    def edit(self):
        return self._edit
    @edit.setter
    def edit(self, edit):
        for choice in Edit:
            if edit[0].lower() == choice.name[0].lower():
                self._edit = choice
                break

    @property
    def exemptUpdateNames(self):
        return self._exemptUpdateNames
    @exemptUpdateNames.setter
    def exemptUpdateNames(self, exemptUpdateNames):
        self._exemptUpdateNames = exemptUpdateNames

    @property
    def exemptUpdateSuffixes(self):
        return self._exemptUpdateSuffixes
    @exemptUpdateSuffixes.setter
    def exemptUpdateSuffixes(self, exemptUpdateSuffixes):
        self._exemptUpdateSuffixes = exemptUpdateSuffixes

    @property
    def exemptMissingSuffixes(self):
        return self._exemptMissingSuffixes
    @exemptMissingSuffixes.setter
    def exemptMissingSuffixes(self, exemptMissingSuffixes):
        self._exemptMissingSuffixes = exemptMissingSuffixes

    @property
    def gitPathSpecifiers(self):
        return self._gitPathSpecifiers
    @gitPathSpecifiers.setter
    def gitPathSpecifiers(self, gitPathSpecifiers):
        self._gitPathSpecifiers = tuple(gitPathSpecifiers)

    @property
    def noticesIgnorePath(self):
        return self._noticesIgnorePath
    @noticesIgnorePath.setter
    def noticesIgnorePath(self, noticesIgnorePath):
        self._noticesIgnorePath = Path(noticesIgnorePath)

    @property
    def noticeTemplatePath(self):
        return self._noticeTemplatePath
    @noticeTemplatePath.setter
    def noticeTemplatePath(self, noticeTemplatePath):
        self._noticeTemplatePath = Path(noticeTemplatePath)

    @property
    def stopAfter(self):
        return self._stopAfter
    @stopAfter.setter
    def stopAfter(self, stopAfter):
        self._stopAfter = stopAfter

    @property
    def summariseFirst(self):
        return self._summariseFirst
    @summariseFirst.setter
    def summariseFirst(self, summariseFirst):
        self._summariseFirst = summariseFirst

    @property
    def verbose(self):
        return self._verbose
    @verbose.setter
    def verbose(self, verbose):
        self._verbose = verbose

    # End of CLI properties.

    def __init__(self):
        # Set default values for CLI properties.
        self._gitPathSpecifiers = tuple()
        self._exemptUpdateNames = (
            'gradlew', 'gradlew.bat', 'gradle-wrapper.properties'
            , 'CODE-OF-CONDUCT.md')
        self._exemptUpdateSuffixes = ('.png', '.json', '.jar')
        self._exemptMissingSuffixes = ('.md', '.txt')
        # Markdown and txt files have different copyright notices, longer and
        # typically appended in a legal section. So if a text file is missing a
        # notice, it can't be added automatically.  
        # If the notice is only incorrect for its date then it can be corrected
        # automatically.

        templatePath = Path(__file__).resolve().parent / "copyright.txt"
        try:
            self._noticeTemplatePath = templatePath.relative_to(
                Path().resolve())
        except ValueError:
            self._noticeTemplatePath = templatePath

        ignorePath = Path('notices.ignore').resolve()
        try:
            self._noticesIgnorePath = ignorePath.relative_to(Path().resolve())
        except ValueError:
            self._noticesIgnorePath = ignorePath
        # End of default CLI properties.

        self._noticedFiles = []

    def __call__(self):
        self._overwrite = Overwrite(self.edit.value)
        self._editor = NoticeEditor.from_template(self.noticeTemplatePath)
        self._ignoreMatcher = PathMatcher.from_ignore_file(
            self.noticesIgnorePath)
        
        self.__scan_files()
        if self.__print_errors() > 0: return 1
        self.__print_summary()
        if self.summariseFirst:
            for noticed in self._noticedFiles:
                self.__correct_one_date(noticed)
            for noticed in self._noticedFiles:
                self.__correct_one_missing(noticed)
        return 0
    
    def __scan_files(self):
        if self.verbose:
            print("Scanning...")
            print(f"Ignoring patterns {self._ignoreMatcher.patterns}")
        else:
            print("Scan dots:")
            for state in NoticeState: print(state.value, state.name)
        stopCount = 0
        ignoreCount = 0
        for path in git_ls_files(self.gitPathSpecifiers):
            ignorePattern = self._ignoreMatcher(path)
            if ignorePattern is None:
                stopCount += 1
                noticed = self.__scan_one_file(path)
                if self.verbose: print(noticed, flush=True)
                else: print(noticed.state.value, end='', flush=True)
                self._noticedFiles.append(noticed)
            else:
                ignoreCount += 1
                if self.verbose: print(
                    f'{path}\nIgnored by pattern "{ignorePattern}"'
                    , flush=True)

            if self.stopAfter > 0 and stopCount >= self.stopAfter: break

        if not self.verbose: print()
        print(f"Path count: {stopCount}.")
        print(f"Ignore count: {ignoreCount}.")
    
    def __scan_one_file(self, path):
        if (
            path.suffix in self.exemptUpdateSuffixes
            or path.name in self.exemptUpdateNames
        ): return NoticedFile.from_exempt_path(path)

        while True:
            noticed = NoticedFile.from_path(path)
            if (not(
                noticed.exception is None
                or type(noticed.exception) is UnicodeDecodeError
            )): raise RuntimeError(path) from noticed.exception

            # If summarising first, don't do any corrections now.
            if self.summariseFirst: return noticed
            
            # If any correction is made, go around again and refresh the file
            # state.
            if self.__correct_one_date(noticed): continue
            try:
                if self.__correct_one_missing(noticed): continue
            except Exception as exception:
                # A KeyError will be thrown if the file suffix isn't known to
                # NoticeEditor.
                return noticed.with_exception(exception)

            # If the code gets here there were no corrections to make, or the
            # user chose not to make them.
            return noticed

    def __print_errors(self):
        errorCount = 0
        for noticed in self._noticedFiles:
            if noticed.exception is None: continue
            errorCount += 1
            print(noticed.path)
            print(f"Raised {type(noticed.exception).__name__}.")
            if type(noticed.exception) is UnicodeDecodeError:
                print(
                    f'Should the suffix "{noticed.path.suffix}" be an exempt'
                    " binary format?")
            else:
                print("\n".join(noticed.exception.args))
        return errorCount

    def __print_summary(self):
        formats = {}
        noticeSuffixes = {}
        for noticed in self._noticedFiles:
            fileFormat = (
                noticed.path.name if (
                    noticed.path.name in self.exemptUpdateNames
                    or noticed.path.suffix == ""
                ) else noticed.path.suffix
            )
            if fileFormat not in formats: formats[fileFormat] = {}
            if noticed.state.name not in formats[fileFormat]:
                formats[fileFormat][noticed.state.name] = []
            formats[fileFormat][noticed.state.name].append(noticed.path)

            noticeSuffix = (
                ascii(None) if (
                    noticed.notice is None or noticed.notice.suffix is None
                ) else noticed.notice.suffix)
            if noticeSuffix not in noticeSuffixes:
                noticeSuffixes[noticeSuffix] = []
            noticeSuffixes[noticeSuffix].append(noticed.path)

        indent = " " * 4
        print("\nSummary by file format or exempt name and state:")
        for fileFormat in sorted(formats.keys()):
            print(fileFormat)
            states = formats[fileFormat]
            for state in sorted(states.keys()):
                print(''.join((
                    indent, state, ": ", first_or_len(states[state]) )))
        print("\nSummary by copyright:")
        for noticeSuffix in sorted(noticeSuffixes.keys()):
            print(
                str_quote(None if noticeSuffix == ascii(None) else noticeSuffix)
                , first_or_len(noticeSuffixes[noticeSuffix]))

    def __correct_one_date(self, noticedFile):
        if noticedFile.state is not NoticeState.INCORRECT_DATE: return False

        # The next line could instead say this.
        #
        #     editedPath = noticedFile.notice.rewrite_year(
        #         noticedFile.modifiedDate.year)
        #
        # That seems theoretically correct. In practice however a change to the
        # copyright year would also be a change to the file that has to be
        # committed. That means the correct year is the current year. Omitting
        # the parameter causes rewrite_year() to fill in the current year.
        editedPath = noticedFile.notice.rewrite_year()
            
        return self._overwrite.prompt(noticedFile.path, editedPath)

    def __correct_one_missing(self, noticedFile):
        if (
            noticedFile.state is NoticeState.MISSING
            and noticedFile.path.suffix not in self._exemptMissingSuffixes
        ):
            editedPath = self._editor(noticedFile.path)
            return self._overwrite.prompt(noticedFile.path, editedPath)

        return False
