#!/bin/sh

# A tool designed to use the default mailto handler and send a notice to the ticketing system for users to request software.
# If the mailto handler is not set, it will fail to start a new message.


#Start logging
log_file="/Library/Logs/appRequest.log"
touch "$log_file"
exec >> $log_file 2>&1
echo "This will be logged to the file and to the screen"



# Jss API Info
jssURL="https://jss.eut.maine.edu:8443"
apiUser="$5"

# User EA to update when requested
xmlUserReqEA="<user><extension_attributes><extension_attribute><name>AppRequest: Adobe Acrobat Pro 2020</name><value>Requested</value></extension_attribute></extension_attributes></user>"
xmlComputerReqEA="<computer><extension_attributes><extension_attribute><name>AppRequestComputer_AdobeAcrobat2020</name><value>Requested</value></extension_attribute></extension_attributes></computer>"

# Gather the user information from the logged on user.
# username of the primary user.
# If no primary user has been set, look up local user
userName=$3
if [[ "$userName" == "" ]]; then
  userName=$( /usr/bin/stat -f %Su /dev/console )
fi
echo "$userName"

#user full name on record
userFullName=$( dscl . read /Users/$userName RealName | awk '{print}' | cut -d ':' -f2 | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' )
echo "$userFullName"

### Check for browsers and mailto handler
# Google Chrome
googleChrome=$( find "/Applications" -type d -maxdepth 1 -name "Google Chrome.app" )
# FireFox
firefox=$( find "/Applications" -type d -maxdepth 1 -name "Firefox.app" )
# Safari
safari=$( find "/Applications" -type d -maxdepth 1 -name "Safari.app" )


####################################################
# Gather system information from computer and JAMF.
# Get device serial number
serialNumber=`ioreg -l | grep IOPlatformSerialNumber|awk '{print $4}' | cut -d \" -f 2`
echo "$serialNumber"

# Get the department information for the user
jUserInfo=$( curl -X GET "$jssURL/JSSResource/computers/serialnumber/$serialNumber/subset/location" -H "accept: application/xml" --header "authorization: Basic $apiUser" )
echo "$jUserInfo"

# Get the Campus affiliation for the user
juserLoc=$( echo $jUserInfo | /usr/bin/awk -F'<building>|</building>' '{print $2}' )
echo "$juserLoc"

# Get the department affiliation for the user
juserDept=$( echo $jUserInfo | /usr/bin/awk -F'<department>|</department>' '{print $2}' )
echo "$juserDept"

# Try to check phone number if available
juserPhone=$( echo $jUserInfo | /usr/bin/awk -F'<phone>|</phone>' '{print $2}' )
echo "$juserPhone"

# application name from parameter 4
appName="$4"
echo "$appName"

####################################################
# Setup text for the email
#subject
subject="Application Request for $appName"
#subjectURL=`echo $subject | sed 's/ /%20/g'`

# set the message we are going to send
message1="I would like to request an application for my Mac.
The application is: $appName
My Mac's system info is:
Serial Number: $serialNumber
Username: $userName
Full Name: $userFullName
Campus: $juserLoc
Department: $juserDept
Campus Phone: $juserPhone

Thanks,
"

# set the destination address
emailAdd="$6"
emailCC="$7"

# prepare email URL
messageURL=`echo "mailto:$emailAdd?cc=$emailCC&subject=$subject&body=$message1" | sed 's/ /+/g'`
echo "Ready to send email"

# try to use google chrome to launch the email, if that isn't installed, use firefox, then try safari
if [[ -e "$googleChrome" ]]; then
  # open google if found
  /usr/bin/open -a "$googleChrome" "$messageURL"

elif [[ -e "$firefox" ]]; then
  # use FireFox
  /usr/bin/open -a "$firefox" "$messageURL"

elif [[ -e "$safari" ]]; then
  # use safari if nothing else is there
  /usr/bin/open -a "$safari" "$messageURL"

fi

#wait until the app launches and user signs in
sleep 15

#Create a receipt to mark that it was run.
echo "Email message created, user should click send." >> "/Library/Application Support/JAMF/Receipts/appRequest_$appName.txt"

#mark the user and computer as requested in JAMF
curl -X PUT "$jssURL/JSSResource/users/name/$userName" -H "Content-Type: text/xml" -d "$xmlUserReqEA" --header "authorization: Basic $apiUser"
curl -X PUT "$jssURL/JSSResource/computers/serialnumber/$serialNumber" -H "Content-Type: text/xml" -d "$xmlComputerReqEA" --header "authorization: Basic $apiUser"

exit 0
