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

# Check if IBM SPSS Statistic software is installed.
# Relicense it with the latest activation key.

#########################
# Variables & Paths     #
#########################

spssVersion=$4 #SPSS Version
spssPath="/Applications/IBM/SPSS/Statistics/$spssVersion/SPSSStatistics.app" #Path to app bundle
spssBin="$spssPath/Contents/bin" #Bin folder with licenseactivator
authKey=$5 #Valid authorization key
jamfReceipt="/Library/Application Support/JAMF/Receipts/spss26Activated.txt" #Receipt file for scoping purposes


######################
# Main script        #
######################

if [[ -e "$spssPath" ]]; then
        echo "$spssPath Found, continuing..."
        "$spssBin/licenseactivator" $authKey
        touch "$jamfReceipt"
        echo "done" > "$jamfReceipt"
    else
        echo "SPSS not found at $spssPath.\nSPSSStatistics.app might be installed at an alternate location.\nRecommend manual re-license"
fi

exit 0
