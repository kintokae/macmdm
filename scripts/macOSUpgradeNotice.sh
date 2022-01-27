#!/bin/bash

#description text
descText="
This machine has been identified as running an old operating system.
macOS 10.13.6 (High Sierra) and older are no longer updated by Apple.

IT has provided a utility to upgrade via Self Service.
We recommend upgrading to macOS 10.14.6 (Mojave) and relaunching your applications to ensure they open correctly.
If this machine is not running any specialized software, we recommend upgrading to macOS 10.15 (Catalina).

Clicking Okay does NOT start the upgrade. Please visit the following URL to learn how to upgrade.
"[Link to your documentation]"

Please contact your local Help Desk if you have questions.
UTSC:
Telephone: (555) 555-5555
Email: help@yourdomain.com
"

#launch jamfHelper to announce
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType hud -windowPosition ul -heading "macOS Upgrade Available" -description "$descText"  -alignDescription left -icon "icon.png" -iconSize 128 -button1 Okay -defaultButton 0
