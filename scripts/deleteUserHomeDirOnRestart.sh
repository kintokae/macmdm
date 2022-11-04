#!/bin/sh

#  deleteUserHomeDirOnRestart.sh
#
# This tool is meant to execute from a policy on start up from JAMF
# Create a policy in jamf, add a label for param 4 and populate it with your admin account.
# Set the trigger to 'startup' and have the computer reboot on logout.
# The user account preference from com.apple.loginwindow is checked against the admin user list and deleted if not in the list.
#
#  Created by Kintokae on 9/5/19.
#  Updated 2022-11-04
#   -> Fixed user logged in statement.
#   -> Added more comments.
#
########################
# Variables and arrays #
########################

# used with jamf param 4 to identify a name in the policy
localAdmin="$4"

# Get the current user info
userLoggedIn=`ls -l /dev/console | awk '/ / { print $3 }'`
lastUserName=$(defaults read /Library/Preferences/com.apple.loginwindow.plist lastUserName)

# Preset the userFound var to false and switch to true if an account has been found for deletion.
userFound="False"

# Add admin accounts and static users that you want to stay
# Usually faculty that are teaching in a classroom get added to this list.
declare -a admin_array=(
    "$localAdmin"
)


########################
#     Main Script      #
########################

# Below is the main script that will check the account, if it doesn't match an identified account from the array, it will delete it.


# Check to see if a user is logged in first, exit if they are.
# If jamf is delayed in running the script on startup, 
if [[ "$userLoggedIn" != '' ]]; then
    echo "User logged in!"
    exit 1
fi


# Check for admin account
# If the account logging in is not
# in the admin array, delete it.

for adminUser in "${admin_array[@]}"; do
    echo "Testing for $adminUser"
    if [[ "$lastUserName" == "$adminUser" ]]; then
        echo "$adminUser logged in last, exiting..."
        exit 0
    fi
done

# Run through and delete the user's profile and account.
# Sometimes deleting the user folder left parts of the library behind.
if [[ -e "/Users/$lastUserName" ]]; then
    /bin/rm -Rf "/Users/$lastUserName/Library"
    /bin/rm -Rf "/Users/$lastUserName"
    echo "Removed folder: $lastUserName"

    ## Delete the account if it exists and not the admin account
    /usr/local/bin/jamf deleteAccount -username "$lastUserName" -deleteHomeDirectory
    echo "acount $lastUserName deleted"
else
    echo "Nothing to do!"
fi


exit 0
