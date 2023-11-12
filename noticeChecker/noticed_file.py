# Copyright 2023 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

# Run with Python 3.9 or later.
"""File in the noticeChecker module."""
#
# Standard library imports, in alphabetic order.
#
# Date module.
# https://docs.python.org/3/library/datetime.html
import datetime
#
# Enumeration class module.
# https://docs.python.org/3/library/enum.html
import enum
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Module for simple immutable objects with type specification.
# https://docs.python.org/3/library/typing.html#typing.NamedTuple
from typing import NamedTuple
#
# Local imports.
#
from noticeChecker.copyright_notice import DiscoveredNotice
from noticeChecker.git_cli import git_ls_files, git_modified_date

def str_quote(subject):
    return (
        "None" if subject is None
        else str(subject) if type(subject) == int
        else ascii(subject).replace("\t", "\\t")
    )

class NoticeState(enum.Enum):
    EXEMPT = "-"
    MISSING = "0"
    CORRECT = "."
    INCORRECT_DATE = "X"
    ERROR = "!"

class NoticedFile(NamedTuple):
    path: Path
    gitModifiedDate: datetime
    notice: DiscoveredNotice
    state: NoticeState
    exception: Exception

    def __str__(self):
        summary = [self.state.name,]
        if self.gitModifiedDate is not None or self.notice is not None:
            summary.append(str(self.gitModifiedDate))
            if self.notice is None:
                summary.append(str(None))
            else:
                summary.extend(
                    str_quote(item) for item in (
                        self.notice.style, self.notice.year, self.notice.suffix
                    )
                )
        return "\n".join((str(self.path), " ".join(summary)))
    
    def with_exception(self, exception):
        return type(self)(
            self.path, self.gitModifiedDate, self.notice, self.state, exception)

    @classmethod
    def from_path(cls, path):
        return cls.from_path_and_git_date(path, git_modified_date(path))
    
    @classmethod
    def from_path_and_git_date(cls, path, gitModifiedDate):
        try:
            notice = DiscoveredNotice.from_path(path)
            return cls(
                path, gitModifiedDate,
                None if notice.style is None else notice,
                NoticeState.MISSING if notice.style is None else
                NoticeState.INCORRECT_DATE
                if notice.year != gitModifiedDate.year
                else NoticeState.CORRECT
                , None
            )
        except UnicodeDecodeError as exception:
            return cls(path, None, None, NoticeState.ERROR, exception)

    @classmethod
    def from_exempt_path(cls, path):
        return cls(path, None, None, NoticeState.EXEMPT, None)
