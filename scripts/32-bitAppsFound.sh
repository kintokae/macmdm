#!/bin/bash

# set Internal Field Separator (IFS) to newline
# this accomodates app titles/directories with spaces
IFS=$'\n'

# perform `mdfind` search; save it to "SEARCH_OUTPUT"
SEARCH_OUTPUT="$(/usr/bin/mdfind "kMDItemExecutableArchitectures == 'i386' && \
kMDItemExecutableArchitectures != 'x86_64' && \
kMDItemKind == 'Application'" \
-onlyin "/Applications" -onlyin "/System" -onlyin "/Library" -onlyin "/Users")"

# create an empty array to save the app names to
APPS=()

# loop through the search output; add the applications to the array
for i in $SEARCH_OUTPUT; do
# use `basename` to strip out the directory path
    b=$( /usr/bin/basename -a "$i" )
    APPS+=("$b")
done

# Extension Attribute; if the array is empty, return 0; otherwise return the length
if [ ${#APPS[@]} == 0 ]; then
    echo "<result>0</result>"
else
    echo "<result>${#APPS[@]}</result>"
fi
