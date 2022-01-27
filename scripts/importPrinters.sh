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

usage="$(basename $0) [-h] [-s server] [-p printer queue name] [-l location] [-u user] -- A tool for updating policies based on a text list of policy ids.

where:
    -h show this help text
    -s set the server name (Ex: myorg.jamfcloud.com, myorg.example.com:8443)
    -u username of a privileged user with CRUD/API access
    -p printer name
    -l printer location"


while getopts s:p:l:u:h option
    do
        case "${option}"
            in
                s) serverName=${OPTARG};;
                p) printerName=${OPTARG};;
                l) location=${OPTARG};;
                u) userID=${OPTARG};;
                h) echo "\n$usage\n\n"
                    exit
                    ;;
        esac
done

#check and set server name
if [[ "$serverName" == "" ]]; then
    echo "Server not set."
fi

if [[ "$printerName" == "" ]]; then
    echo "Printer not set."
    exit 1
fi

#check location and set
if [[ "$location" == "" ]]; then
    location="$printerName"
fi

#Configure context import printer
# Update the <uri>ipp:// with your cups server
printerData="
    <printer>
    <name>$printerName</name>
    <category>Printers</category>
    <uri>ipp://{$CUPS_Server}/printers/$printerName</uri>
    <CUPS_name>$printerName</CUPS_name>
    <location>$location</location>
    <shared>false</shared>
    <info>Papercut Printer -- $printerName</info>
    </printer>"

#Add a printer
if [[ serverName != "" && userName != "" ]]; then
    curl -k -X POST -su "$userID" -H 'Content-Type: text/xml' -d "$printerData" "https://$serverName/JSSResource/printers/id/0"
else
    echo "Username or Server were not set"
    exit 401
fi

exit 0
