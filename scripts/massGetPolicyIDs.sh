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
#  massGetPolicyIDs.sh
#       A tool for getting policy ids to a text file for manipulating policies.
#
#Create flags for passing in paramters
#   Help Usage
usage="$(basename $0) [-h] [-s server] [-c category] [-u user] \n\nA tool for getting policy ids to a text file for manipulating policies.\nThe retrieved policy ids will be saved to '~/Documents/legacyPolicies.txt'

where:
    -h show this help text
    -s set the server name (Ex: myorg.jamfcloud.com, myorg.example.com:8443)
    -u username of a privileged user with CRUD/API access
    -c category name the policies are grouped to"
    

while getopts s:c:u:h option
    do
        case "${option}"
            in
                s) serverName=${OPTARG};;
                c) catName=${OPTARG};;
                u) userID=${OPTARG};;
                h) echo "\n$usage\n\n"
                    exit
                    ;;
        esac
done

# Print out info provided.
echo "Server Name: $serverName"
echo "Group Name: $catName"


# user id of a privileged user.
#userID=$3
echo "Privileged UserID: $userID"


# Get policies from JAMF based on group
if [[ serverName != "" || userName != "" ]]; then
    curl -X GET -su $userID "https://$serverName/JSSResource/policies/category/$catName" --header 'content-type: application/xml' | xmllint --format - | awk -F'>|<' '/<id>/{print $3}' | sort -n -o ~/Documents/legacyPolicies.txt
fi

exit 0
