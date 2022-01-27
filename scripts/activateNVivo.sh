#!/bin/sh
#
#
#Copyright 2019 Eric Pomelow
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#
#
#########
# Find and activate NVivo app for users silently with key and file
#########
#
# Current logged in user.
currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

# Cut username into first & last name
firstName=$(dscl . -read /Users/$currentUser RecordName | cut -d '.' -f 1 | awk '{print $2}')
lastName=$(dscl . -read /Users/$currentUser RecordName | cut -d '.' -f 2)

# activation key
activationKey="$4"
if [[ "$activationKey" != "" ]]; then
    echo "$activationKey"
fi

# Find nVivo app in applications folder
nvivoApp=$(ls -ld /Applications/NVivo* | cut -d '/' -f 3 | cut -d '.' -f 1)

if [[ $nvivoApp != "" ]]; then
    echo "NVivo App found: $nvivoApp"
    "/Applications/$nvivoApp.app/Contents/MacOS/$nvivoApp" -initialize "$activationKey"
    else
        echo "NVivo App not found."
fi

exit 0
