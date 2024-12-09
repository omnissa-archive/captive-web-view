# Copyright 2023 Omnissa, LLC.
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
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Temporary file module.
# https://docs.python.org/3/library/tempfile.html
from tempfile import NamedTemporaryFile

leaderSuffixesMap = {
     "#": ('.gitignore', '.ignore', '.pro', '.properties', '.py'),
    "//": ('.gradle', '.java', '.kt', '.swift')
}

xmlSuffixes = ('.xml', '.html', ".xcworkspacedata")

def comment_leader(path):
    suffix = path.suffix
    for key, suffixList in leaderSuffixesMap.items():
        if suffix in suffixList:
            return key
    raise KeyError(f'No comment leader configured for file suffix "{suffix}".')

def editing_file(path):
    return  NamedTemporaryFile(
        mode='w', delete=False, prefix=path.stem + '_' , suffix=path.suffix)

def starts_with(path, start):
    mode = 'b' if type(start) is bytes else ''
    with Path(path).open('r' + mode) as file:
        actual = file.read(len(start))
        return actual == start

class NoticeEditor:
    def __init__(self, noticeLines):
        self._noticeLines = tuple(noticeLines)
    
    @classmethod
    def from_template(cls, path, date=None):
        if date is None:
            date = datetime.datetime.now()
        with Path(path).open() as file: return cls(tuple(
            date.strftime(line.rstrip()) for line in file.readlines()
        ))

    def __call__(self, path):
        if path.suffix in xmlSuffixes or starts_with(path, b'<?xml'):
            return self.xml_editor(path)

        if starts_with(path, b'// !$*UTF8*$!'):
            return self.pbxproj_editor(path)

        return self.comment_leader_editor(path)
        # Previous line will raise KeyError if there's no known leader for the
        # suffix.

    # Simple editor that inserts the notices at the start of the file.
    #
    # Each notice line is prefixed by a comment leader and a space.  
    # If the first line of the original file wasn't a blank line, then a blank
    # line is inserted after the notice lines.  
    # Then append the rest of the original file.
    def comment_leader_editor(self, path, commentLeader=None):
        if commentLeader is None:
            commentLeader = comment_leader(path)
        if commentLeader is None: return None # No comment leader configured.

        with editing_file(path) as editedFile, path.open('r') as originalFile:
            for line in self._noticeLines:
                editedFile.write(commentLeader)
                editedFile.write(" ")
                editedFile.write(line)
                editedFile.write("\n")

            for index, line in enumerate(originalFile):
                if index == 0 and line.strip() != "":
                    editedFile.write("\n")
                editedFile.write(line)

            return Path(editedFile.name)

    # Custom editor for XML files.
    #
    # If the first line is an XML declaration, put the notices XML comment after
    # it. Otherwise, put the notices first. Then append the rest of the file
    # unchanged.
    #
    # Simple way to identify the XML declaration is that it starts `<?xml` or
    # `<!DOCTYPE `.
    #
    # This code mightn't behave correctly if the xml file is empty. That
    # probably isn't valid XML anyway.
    def xml_editor(self, path):
        noticesXML = "\n".join((
            "<!--", *["    " + line for line in self._noticeLines], "-->\n"))

        with editing_file(path) as editedFile, path.open('r') as originalFile:
            line = originalFile.readline()
            if line.startswith("<?xml") or line.startswith('<!DOCTYPE '):
                editedFile.write(line)
                editedFile.write(noticesXML)
            else:
                editedFile.write(noticesXML)
                editedFile.write(line)
            line = originalFile.readline()
            while line != '':
                editedFile.write(line)
                line = originalFile.readline()
            return Path(editedFile.name)

        # Following code would do something more fancy. It looks for the first
        # end tag, `>` character, and then inserts the notice XML comment after
        # it. The output wasn't as clean, and is different to what Jim did in
        # another Open Source repository, so it's commented out.
        #
        # inserted = False
        # while line != '':
        #     if inserted:
        #         editedFile.write(line)
        #     else:
        #         partition = line.partition('>')
        #         editedFile.write(partition[0])
        #         editedFile.write(partition[1])
        #         if partition[1] != '':
        #             if partition[0].endswith("?"):
        #                 editedFile.write("\n")
        #             editedFile.write("\n".join((
        #                 "<!--", *self._noticeLines, "-->"
        #             )))
        #             inserted = True
        #         editedFile.write(partition[2])
        #     line = originalFile.readline()

    # Custom editor for .pbxproj files.
    #
    # Copy the first line to the edited file.
    #
    # Insert the copyright notice lines like this.
    #
    #     /* Notice line 1.
    #      * Notice line 2.
    #      * Notice line 3.
    #      */
    #
    # Copy the rest of the file to the edited file.
    def pbxproj_editor(self, path):
        with editing_file(path) as editedFile, path.open('r') as originalFile:
            line = originalFile.readline()
            editedFile.write(line)
            editedFile.write('/* ')
            editedFile.write("\n * ".join(self._noticeLines))
            editedFile.write('\n */\n')
            line = originalFile.readline()
            while line != '':
                editedFile.write(line)
                line = originalFile.readline()
            return Path(editedFile.name)
