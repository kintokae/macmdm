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
#  massAddToSmartGroup.sh
#       A tool for mass updating or adding to a smart group
#
#Create flags for passing in paramters
#   Help Usage
usage="$(basename $0) [-h] [-s server] [-f file name] [-u username & password] -- A tool for mass updating or adding to a smart group

where:
    -h show this help text
    -s set the server name (Ex: myorg.jamfcloud.com, myorg.example.com:8443)
    -u username and password for privileged user (username:password)
    -f file name with usernames to add
    -c computer group ID, se the group ID number from the URL of the group (Ex: myorg.jamfcloud.com/smartComputerGroups.html?id=309&o=r)"


while getopts s:f:u:c:h option
    do
        case "${option}"
            in
                s) serverName=${OPTARG};;
                f) fileName=${OPTARG};;
                u) user=${OPTARG};;
                c) id=${OPTARG};;
                h) echo "\n$usage\n\n"
                    exit
                    ;;
        esac
done

# Print out info provided.
echo "Server Name: $serverName"
echo "Filename: $fileName"
echo "Computer group ID: $id"

# Set the content type to be deleted, policies or osxconfigurationprofiles
    if [[ "$serverName" = "" ]]; then
        echo "Please set a server name, use -s serverName"
        exit 1
    fi

# Check if user or authString are set.
# Continue if either are set.
    if [[ $user == "" ]]; then
        echo "No user account specified.  Please use -u username:password"
        exit 1
    fi

# Set the computer group id number
    if [[ "$id" = "" ]]; then
        echo "Please set an ID type to edit, use -c '309'"
        exit 1
    fi

# Add user to computer smart group criteria in a loop through the text file
    # set line number to zero to add users incrementally.
    lineNumber=0
    groupSize=1
    echo "<computer_group>
    <criteria>" > /tmp/boxAppGroup.xml
    if [[ $fileName != "" ]]; then
        while IFS= read -r line; do
            echo "Adding $line"
            echo "<criterion><name>Local User Accounts</name><priority>$lineNumber</priority><and_or>or</and_or><search_type>has</search_type><value>$line</value><opening_paren>false</opening_paren><closing_paren>false</closing_paren></criterion>" >> /tmp/boxAppGroup.txt
            #curl -X PUT "https://$serverName/JSSResource/computergroups/id/$id" -H "accept: application/xml" -H "Content-Type: application/xml" -d "<computer_group><criteria><size>$groupSize</size><criterion><name>Local User Accounts</name><priority>$lineNumber</priority><and_or>or</and_or><search_type>has</search_type><value>$line</value><opening_paren>false</opening_paren><closing_paren>false</closing_paren></criterion></criteria></computer_group>" --user $user
            lineNumber=$((lineNumber+1))
            #groupSize=$((groupSize+1))
        done < $fileName
        echo "</criteria>
        </computer_group>" >> /tmp/boxAppGroup.txt
    fi
exit 0
