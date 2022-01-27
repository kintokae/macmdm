#!/bin/sh

# Current user
currentUser=`ls -l /dev/console | awk '/ / { print $3 }'`

#find the user's box and onedrive folder
dropboxFolder=$(find "/Users/$currentUser" -type d -maxdepth 1 -name "Dropbox")
onedrive=$(find "/Users/$currentUser" -type d -maxdepth 1 -name "OneDrive")

# Output file location
outputFile="/Users/$currentUser/Desktop/fileReport.txt"

# Run sync on folders
if [[ -e "$dropboxFolder" && "$OneDrive" ]]; then
  rsync -avz "$dropboxFolder" "$onedrive/MigratedFromDropbox" > "$outputFile"
else
  echo "Dropbox folder not found" > "$outputFile"
fi

exit 0
