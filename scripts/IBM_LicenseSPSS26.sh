#!/bin/sh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# SYSTEM CHECKS
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Get Current User
currentUser=$( /usr/bin/stat -f %Su /dev/console )

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# FUNCTIONS
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

cleanExit() {
## Remove Script
/bin/rm -f "/Library/filesCache/installer.properties"
/bin/rm -f "/Library/filesCache/SPSS_Statistics_Installer.bin"
exit "$1"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# VARIABLES
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#choose license type in parameter 4 of the script options, su for single user or mu for multiuser
#once selected, the corresponding parameter must be set
#default is to use single.

licenseType=$4
if [ "$licenseType" != "mu" ]; then licenseType=su ; fi

#License Server
lserver=$5

#Single User AuthCode

authSerial=$6

#  IBM SPSS 26 installer properties
#
#
#  Created by eric.pomelow on 8/16/19.
#  Used to post property text and autolicense spss app to either a server or a single user.

# set license based on license type for installation.
# If the license type is single user then the authcode will be appended to the top of the properties file.  If the license type is multi user then the server will be added.

if [ "$licenseType" == "mu" ]; then
echo LSHOST=$lserver > "/Library/filesCache/installer.properties"
else echo AUTHCODE=$authSerial > "/Library/filesCache/installer.properties"
fi

/bin/echo "
################################################################################

# IBM SPSS Statistics 26 silent parameter
INSTALLER_UI=silent

###############################################################################

# IBM SPSS Statistics 26   License Acceptance
#
# license acceptance for silent installers
LICENSE_ACCEPTED=true

################################################################################
#
# IBM SPSS Statistics 26 - Install Python and Python Essentials
#

InstallPython=1

################################################################################
#
# IBM SPSS Statistics 26 - Do Not Install Python and Python Essentials
#

#InstallPython=0

################################################################################
#
# IBM SPSS Statistics 26   LSHOST
#
# The IP addresses or the names of the network computer or computers on which the
# network license manager is running. One or more valid IP addresses or network
#computer names. Multiple addresses or names are separated by colons
#(for example,server1:server2:server3).
#
#

###LSHOST=

################################################################################
#
# IBM SPSS Statistics 26   Authorization Code
#
# The authorization code. If this property is specified, the product is authorized
# automatically using the authorization code. If this property is not specified, each
# end user must run the License AuthorizationWizard to authorize manually. One or more
# valid authorization codes. Multiple authorization codes are separated by colons (for example, authcode1:authcode2).
#
#

###AUTHCODE=<value>

################################################################################
#
# IBM SPSS Statistics 26 COMMUTE_MAX_LIFE
#
# Set the Number of days the commuter license can be checked out.
#
# Do not comment out this setting. It must always specify some value.
#

COMMUTE_MAX_LIFE=7

######################################
" >> /Library/filesCache/installer.properties

/bin/sleep 3

#set permissions for the properties file
/usr/sbin/chown "{jss-mgmt-acct}" '/Library/filesCache/installer.properties'
/usr/sbin/chown "{jss-mgmt-acct}" '/Library/filesCache/SPSS_Statistics_Installer.bin'
/bin/chmod 777 '/Library/filesCache/installer.properties'

#check if the package extracted correctly
if [ -f "/Library/filesCache/SPSS_Statistics_Installer.bin" ]; then
echo "SPSS silent installer found, proceeding..."
'/Library/filesCache/SPSS_Statistics_Installer.bin' -f '/Library/filesCache/installer.properties'
else echo "SPSS was not extracted."
fi

cleanExit 0
