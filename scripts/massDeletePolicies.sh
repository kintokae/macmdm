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
#  massDeletePolicies.sh
#       A tool for mass deleting policies
#
#Create flags for passing in paramters
#   Help Usage
usage="$(basename $0) [-h] [-s server] [-f file name] [-u username & password] -- A tool for mass deleting policies

where:
    -h show this help text
    -s set the server name (Ex: myorg.jamfcloud.com, myorg.example.com:8443)
    -u username and password for privileged user (username:password)
    -f file name with policy id numbers to delete
    -c content, use policies or osxconfigurationprofiles"
    

while getopts s:f:u:c:h option
    do
        case "${option}"
            in
                s) serverName=${OPTARG};;
                f) fileName=${OPTARG};;
                u) user=${OPTARG};;
                c) content=${OPTARG};;
                h) echo "\n$usage\n\n"
                    exit
                    ;;
        esac
done

# Print out info provided.
echo "Server Name: $serverName"
echo "$content ID: $fileName"

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

# Set the content type to be deleted, policies or osxconfigurationprofiles
    if [[ "$content" = "" ]]; then
        echo "Please set a content type to edit, use -c 'policies' or osxconfigurationprofiles'"
        exit 1
    fi

# delete policy in a loop through the text file
    if [[ $fileName != "" ]]; then
        while IFS= read -r line; do
            echo "Deleting policy ID: $line"
            curl -X DELETE "https://$serverName/JSSResource/$content/id/$line" --user $user
        done < $fileName
    fi
exit 0
