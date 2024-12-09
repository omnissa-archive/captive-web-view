# Copyright 2023 Omnissa, LLC.
# SPDX-License-Identifier: BSD-2-Clause

# Run with Python 3.9 or later.
"""File in the noticeChecker module."""
#
# Standard library imports, in alphabetic order.
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Module for simple immutable objects with type specification.
# https://docs.python.org/3/library/typing.html#typing.NamedTuple
from typing import NamedTuple

class PathMatcher(NamedTuple):
    patterns: [str]

    @classmethod
    def from_ignore_file(cls, path):
        return cls(tuple(pattern for pattern in read_ignore_file(path)))
    
    def __call__(self, path):
        for pattern in self.patterns:
            if matches(path, pattern): return pattern
        return None

# Read the patterns from a .gitignore type of file format. Discard comments and
# blank space.
def read_ignore_file(path):
    path = Path(path)
    if not path.exists(): return
    with path.open('r') as file:
        for line in file.read().splitlines():
            stripped = line.strip()
            if stripped != "" and not stripped.startswith('#'):
                yield stripped

def matches(path, pattern):
    return matches_transcript(path, pattern)[0]

def matches_transcript(path, pattern):
    path = Path(path)
    pathParts = tuple(Path(part) for part in path.parts)
    pattern = Path(pattern)
    pathIndex = len(pathParts) - 1
    transcript = [
        f'path: {tuple(str(part) for part in pathParts)}',
        f'pattern: {pattern.parts}'
    ]
    matched = True

    for patternIndex in reversed(range(len(pattern.parts))):
        patternPart = pattern.parts[patternIndex]
        transcript.extend((
            "path[]" if pathIndex < 0 else
            f'path[{pathIndex}]"{str(pathParts[pathIndex])}"',
            f'pattern[{patternIndex}]"{patternPart}"'
        ))
        if patternPart == "**":
            # If ** is the first pattern element, it will match any path. Set
            # needle to None to flag that. It gets checked after the transcript.
            needle = (
                None if patternIndex == 0 else pattern.parts[patternIndex - 1])
            #
            # Collapse **/** to ** by skipping any attempt to find the needle
            # and not consuming any path. The next ** will be processed next
            # time around the loop.
            if needle == "**":
                transcript.append("Collapsing **/**")
                continue
            transcript.append(''.join((
                "**", "" if needle is None else f'"{needle}"',
                f' {tuple(str(part) for part in pathParts[:pathIndex + 1])}'
            )))
            if needle is None: break
            #
            # Consume the path up until the one before the needle. Stop
            # consuming at pathIndex 0  because by then the only chance for a
            # match is pathParts[0] which will be compared next time around the
            # loop.
            while pathIndex > 0:
                transcript.append(
                    f'** path[{pathIndex}]"{str(pathParts[pathIndex])}"')
                if pathParts[pathIndex].match(needle):
                    transcript.append("Found.")
                    break
                pathIndex -= 1
            continue

        if (pathIndex >= 0 and Path(path.parts[pathIndex]).match(patternPart)):
            transcript.append("Match.")
            # Consume one path segment and go around again.
            pathIndex -= 1
            continue

        transcript.append("No match.")
        matched = False
        break

    return matched, transcript
