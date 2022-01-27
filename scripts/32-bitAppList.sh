#!/bin/bash

# set Internal Field Separator (IFS) to newline
# this accomodates app titles/directories with spaces
IFS=$'\n'

# perform `mdfind` search; save it to "SEARCH_OUTPUT"
SEARCH_OUTPUT="$(/usr/bin/mdfind "kMDItemExecutableArchitectures == 'i386' && \
kMDItemExecutableArchitectures != 'x86_64' && \
kMDItemKind == 'Application'" \
-onlyin "/Applications" -onlyin "/System" -onlyin "/Library" -onlyin "/Users")"


# Extension Attribute; if the output is empty, return None; otherwise return the app names
if [ "$SEARCH_OUTPUT" == "" ]; then
    echo "<result>None</result>"
else
    echo "<result>$SEARCH_OUTPUT</result>"
fi
