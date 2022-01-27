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
# Setup AutoCad script will enable admins to set the version
# and servername in the policy to deploy a licensed product.

# Logging file
adskLog="/Library/Logs/autocadInstaller.log"
echo "`date`: Starting installer" >> "$adskLog"

# Server name of license manager
serverName=$4
echo "`date`: License server set to $serverName" >> "$adskLog"

#license server name
licenseString="$serverName" # Change to licenseString for setting up license file

# Set Autodesk license file location.
autoCadYear=$5 # AutoCad annual release
echo "`date`: AutoCAD set to $autoCadYear" >> "$adskLog"

if [[ "$autoCadYear" == "2021" ]]; then
    echo "AutoCad version $autoCadYear, setting up license path." >> "$adskLog"
    licenseFilePath="/Library/Application Support/Autodesk/AdskLicensingService/777M1_$autoCadYear.0.0.F"
    licenseFile="$licenseFilePath/licpath.lic"
else
    echo "AutoCad version $autoCadYear is prior to 2021, setting up license path."  >> "$adskLog"
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

# Autodesk AutoCAD disable welcome screen.

over500=$( dscl . list /Users UniqueID | awk '$2 > 500 { print $1 }' )

# Set pref User Template
/usr/bin/defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.autodesk.AutoCAD$autoCadYear" AutoMigrated -bool TRUE
/usr/sbin/chown root:wheel "/System/Library/User Template/English.lproj/Library/Preferences/com.autodesk.AutoCAD$autoCadYear.plist"

# Set prefs Users
for u in $over500 ;
do
    /usr/bin/defaults write "/System/Library/User Template/English.lproj/Library/Preferences/com.autodesk.AutoCAD$autoCadYear" AutoMigrated -bool TRUE
    /usr/sbin/chown "$u" "/Users/$u/Library/Preferences/com.autodesk.AutoCAD$autoCadYear.plist"
done

# Setup Autodesk AutoCAD 2021
if [[ "$autoCadYear" -ge "2021" ]]; then
     echo "Attaching AutoCAD 2021 DMG" >> "$adskLog"
     /usr/bin/hdiutil attach "/private/var/tmp/Autodesk_AutoCAD_2021_macOS.dmg" -nobrowse
     if [[ -e "/Volumes/Installer/Install AutodeskA AutoCAD 2021 for Mac.app" ]]; then
     	echo "AutoCAD 2021 installer mounted, installing..." >> "$adskLog"
     fi
    sudo /Volumes/Installer/Install\ Autodesk\ AutoCAD\ 2021\ for\ Mac.app/Contents/Helper/Setup.app/Contents/MacOS/Setup -q --hide_eula
    echo "AutoCAD 2021 installer finished" >> "$adskLog"
    echo "Detaching AutoCAD 2021 DMG" >> "$adskLog"
    /usr/bin/hdiutil detach "/Volumes/Installer"
    
    # Licensing Autocad
    /Library/Application\ Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper change --prod_key 777M1 --prod_ver 2021.0.0.F --lic_method "NETWORK" --lic_server_type "SINGLE" --lic_servers "$serverName"

else
    echo "AutoCAD year is prior to 2021, moving on..." >> "$adskLog"
fi

# Set up Autodesk AutoCAD 2019.
if [[ "$autoCadYear" == "2019" ]]; then
    setupFilesPath="/Library/Application Support/Autodesk/CLM/LGS/777K1.0.0.F"
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

# Check if AutoCAD installed correctly
#autoCad=$(ls -ld /Applications/Autodesk* | cut -d '/' -f 3 | cut -d '.' -f 1)

exit 0
