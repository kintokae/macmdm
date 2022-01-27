#!/bin/sh
#
#
#Copyright 2020 Eric Pomelow
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
# Setup Maya script will enable admins to set the version
# and servername in the policy to deploy a licensed product.

# Logging file
adskLog="/Library/Logs/autodeskInstaller.log"
echo "`date`: Starting installer" >> "$adskLog"

# Server name of license manager
serverName=$4
echo "`date`: License server set to $serverName" >> "$adskLog"

#license server name
licenseString="$serverName" # Change to licenseString for setting up license file

# Set Autodesk license file location.
mayaYear=$5 # Maya annual release
echo "`date`: Maya set to $mayaYear" >> "$adskLog"

if [[ "$mayaYear" == "2020" ]]; then
    echo "Maya version $mayaYear, setting up license path." >> "$adskLog"
    licenseFilePath="/Library/Application Support/Autodesk/AdskLicensingService/657L1_$mayaYear.0.0.F"
    licenseFile="$licenseFilePath/licpath.lic"
else
    echo "Maya version $mayaYear is prior to 2020, setting up license path."  >> "$adskLog"
    licenseFilePath="/Library/Application Support/Autodesk/CLM/LGS"
    licenseFile="$licenseFilePath"/"ADSKFLEX_LICENSE_FILE.data"

fi


# Confirm path exists
mkdir -p "$licenseFilePath"

if [[ -e "${licenseFile}" ]]; then
        echo "SERVER $licenseString 000000000000 2080" > "$licenseFile"
        echo "USE_SERVER" >> "$licenseFile"
        echo "License fixed." >> "$adskLog"
else
    echo "License does not exist, creating..."
    echo "SERVER $licenseString 000000000000 2080" > "$licenseFile"
    echo "USE_SERVER" >> "$licenseFile"
    echo "License created." >> "$adskLog"
fi

# Autodesk Maya disable welcome screen.

over500=$( dscl . list /Users UniqueID | awk '$2 > 500 { print $1 }' )

# Set pref User Template
/usr/bin/defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.autodesk.maya$mayaYear" AutoMigrated -bool TRUE
/usr/sbin/chown root:wheel "/System/Library/User Template/English.lproj/Library/Preferences/com.autodesk.maya$mayaYear.plist"

# Set prefs Users
for u in $over500 ;
do
    /usr/bin/defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.autodesk.maya$mayaYear" AutoMigrated -bool TRUE
    /usr/sbin/chown "$u" "/Users/$u/Library/Preferences/com.autodesk.maya$mayaYear.plist"
done

# Setup Autodesk Maya 2020
if [[ "$mayaYear" -ge "2020" ]]; then
     echo "Attaching Maya 2020 DMG" >> "$adskLog"
     /usr/bin/hdiutil attach "/private/var/tmp/Autodesk_Maya_2020_Mac_OSX.dmg" -nobrowse
     if [[ -e "/Volumes/Install Maya 2020/Install Maya 2020.app" ]]; then
     	echo "Maya 2020 installer mounted, installing..." >> "$adskLog"
     fi
    sudo /Volumes/Install\ Maya\ 2020/Install\ Maya\ 2020.app/Contents/Helper/Setup.app/Contents/MacOS/Setup -q --hide_eula
    echo "Maya 2020 installer finished" >> "$adskLog"
    echo "Detaching Maya 2020 DMG" >> "$adskLog"
    /usr/bin/hdiutil detach "/Volumes/Install Maya 2020"
    
    # Licensing Maya
    /Library/Application\ Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper change --prod_key 657L1 --prod_ver 2020.0.0.F --lic_method "NETWORK" --lic_server_type "SINGLE" --lic_servers "$serverName"

else
    echo "Maya year is prior to 2020, moving on..." >> "$adskLog"
fi

# Set up Autodesk Maya 2019.
if [[ "$mayaYear" == "2019" ]]; then
    setupFilesPath="/Library/Application Support/Autodesk/CLM/LGS/657K1.0.0.F"
    lgsFile="$setupFilesPath"/"LGS.data"
    lgsFileString="_NETWORK"
    nwFile="$setupFilesPath"/"nw.cfg"
    nwFileString="done"

    # Confirm LGS.data file exists
    mkdir -p "$setupFilesPath"

    # Confirm LGS.data file
    if [[ -e "${lgsFile}" ]]; then
        if [[ $( cat "${lgsFile}" ) == "${lgsFileString}" ]]; then
            echo "Setup LGS.data file is OK."
        else
            echo "Setup LGS.data file is not OK, fixing..."
            echo "$lgsFileString" > "$lgsFile"
            echo "Setup LGS.data file fixed."
        fi
    else
        echo "Setup LGS.data does not exist, creating..."
        echo "$lgsFileString" > "$lgsFile"
        echo "Setup LGS.data file created."
    fi

    # Confirm nw.cfg file
    if [[ -e "${nwFile}" ]]; then
        if [[ $( cat "${nwFile}" ) == "${nwFileString}" ]]; then
            echo "Setup nw.cfg file is OK."
        else
            echo "Setup nw.cfg file is not OK, fixing..."
            echo "$nwFileString" > "$nwFile"
            echo "Setup nw.cfg file fixed."
        fi
    else
        echo "Setup nw.cfg does not exist, creating..."
        echo "$nwFileString" > "$nwFile"
        echo "Setup nw.cfg file created."
    fi

    #Copy License file to LICPATH.lic

    cp "$licenseFile" "$setupFilesPath"/LICPATH.lic

fi


exit 0
