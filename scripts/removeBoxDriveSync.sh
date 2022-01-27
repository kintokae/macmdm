#!/bin/sh
#
#
#Copyright 2021 Eric Pomelow
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
# Remove Box drive and sync from the user computers.

#######################
# Variables and Paths #
#######################

## Get Current User
currentUser=$( /usr/bin/stat -f %Su /dev/console )

# Add log output
boxRemovalLog="/Library/Logs/removeBox.log"
/usr/bin/touch "$boxRemovalLog"
timeStamp=`date '+%d/%m/%Y_%H:%M:%S'` # time stamp the log
/bin/echo "$timeStamp: Upgrade started" > "$boxRemovalLog"


# Box drive location
boxDrive=$(find "/Applications" -type d -maxdepth 1 -name "Box.app")
# Box Sync location
boxSync=$(find "/Applications" -type d -maxdepth 1 -name "Box Sync.app")

# Box identifiers and locations
BFD_IDENTIFIER="com.box.desktop"
BOX_HELPER_IDENTIFIER=com.box.desktop.helper
BOX_HELPER_PLIST_PATH=/Library/LaunchAgents/$BOX_HELPER_IDENTIFIER.plist
FINDER_EXTENSION_IDENTIFIER=com.box.desktop.findersyncext

# Box cleanup funtions

function unload_user_au_and_helper {
    # Unload the user version of the helper
    /bin/launchctl unload $BOX_HELPER_PLIST_PATH || true
}


#
# Clear out any prefs we've set
#
function clear_user_level_prefs {
    defaults delete /Users/"$currentUser"/Library/Preferences/com.box.desktop.installer || true
    defaults delete /Users/"$currentUser"/Library/Preferences/com.box.desktop.ui || true
    defaults delete /Users/"$currentUser"/Library/Preferences/com.box.desktop || true
}


#
# Disable the Finder extension
#
function disable_finder_extension {
    # Always disable the plugin
    /usr/bin/pluginkit -e ignore -i $FINDER_EXTENSION_IDENTIFIER || true

    # Immediately kill any running processes
    killall -9 FinderSyncExt || true
}

#
# Delete the Box token from the keychain
#
function delete_box_token {
    security delete-generic-password -c aapl -s Box || true
}


#######################
#    System Check     #
#######################
### System check to make sure OS is running 10.14+
macOSVers=$(sw_vers -productVersion)
macOSMajor=$(/bin/echo "$macOSVers" | awk -F'.' '{print $2}')
/bin/echo "$timeStamp: macOS version is $macOSVers" >> "$boxRemovalLog"




#######################
#        Main         #
#######################

# A command-line parameter of "-n" means "don't give up if you can't uninstall FUSE."
# This is intended for AAU use.
#


# Make sure we're clear to go
unload_user_au_and_helper && \
disable_finder_extension


### Remove box app

if [[ -e "$boxDrive" ]]; then
    killall "Box"
    rm -Rf "$boxDrive"
    sudo "${0%/*}/""/Library/Application Support/Box/uninstall_box_drive_r"
else
    echo "Box is not installed." >> "$boxRemovalLog"
fi

### Remove box app

if [[ -e "$boxSync" ]]; then
    rm -Rf "$boxSync"
    rm -Rf "~/Library/Logs/Box/Box Sync/"
    rm -Rf "~/Library/Application Support/Box/Box Sync/"
    rm -Rf "/Library/PrivilegedHelperTools/com.box.sync.bootstrapper"
    rm -Rf "/Library/PrivilegedHelperTools/com.box.sync.iconhelper"
else
    echo "Box Sync is not installed." >> "$boxRemovalLog"
fi

clear_user_level_prefs

# Finished removing box apps.
/bin/echo "$timeStamp: Box app has been removed." >> "$boxRemovalLog"



exit 0
