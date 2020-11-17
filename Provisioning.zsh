#!/bin/zsh


<<'ABOUT_THIS_SCRIPT'
-----------------------------------------------------------------------

	Written by:William Smith
	Professional Services Engineer
	Jamf
	bill@talkingmoose.net
	https://gist.github.com/e1848e3b410395f05c9fcd9ed78386a5
	
	Originally posted: November 19, 2020

	Purpose: Runs when called by a Jamf Pro policy triggered
	by Enrollment Complete.

	1. Prompts user to enter asset tag.
	2. Runs specified policies by trigger name.
	3. Updates inventory.
	4. Restarts computer.
	
	Instructions: Add this script to Jamf Pro and then add it to a new
	Jamf Pro policy triggered by Enrollment Complete. This should be the
	only policy triggered by Enrollment Complete. Edit the $policyList
	below with policy names and policy triggers separated by a comma.
	
	Except where otherwise noted, this work is licensed under
	http://creativecommons.org/licenses/by/4.0/

	“I'm not so sure he's mad, Father. Just a little devious in his sanity.”
	
-----------------------------------------------------------------------
ABOUT_THIS_SCRIPT


# Policy names and policy triggers separated by ","

policyList="Installing Google Chrome,maininstallgooglechrome
Installing Microsoft Office 2019,maininstallmicrosoftoffice
Installing Zoom,main-zoom
Setting Time Zone,settimezonechicago"


# Set variables

logFile="/var/log/Provisioning.log"

function logresult()	{
	if [ $? = 0 ] ; then
	  /bin/date "+%Y-%m-%d %H:%M:%S	$1" >> "$logFile"
	  echo "$1" # for the policy log
	else
	  /bin/date "+%Y-%m-%d %H:%M:%S	$2" >> "$logFile"
	  echo "$2" # for the policy log
	fi
}

# Create log file
/usr/bin/touch $logFile

# Provide path to jamfHelper
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# wait until the Dock process has started
while [[ "$setupProcess" = "" ]]
do
	echo "Waiting for Dock"
	setupProcess=$( /usr/bin/pgrep "Dock" )
	sleep 3
done

sleep 3

# get currently logged in user
currentUser=$( /usr/bin/stat -f "%Su" /dev/console )

echo "Current user is $currentUser"

# prompt for asset tag
while [[ "$assetTag" = "" ]];
do
	theCommand="display dialog \"Enter the asset tag you received for your computer and then affix the sticker to the bottom...\" default answer \"\" with title \"Asset Tag\" buttons {\"Stop\", \"OK\"} default button {\"OK\"} with icon file posix file \"/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns\""
	results=$( /bin/launchctl asuser "$currentUser" sudo -iu "$currentUser" /usr/bin/osascript -e "$theCommand" )
	
	theButton=$( echo "$results" | /usr/bin/awk -F "button returned:|," '{print $2}' )
	assetTag=$( echo "$results" | /usr/bin/awk -F "text returned:" '{print $2}' )
	
	if [ "$theButton" = "Stop" ]; then
		echo "Asset tag prompt canceled. Stopping script."
		exit 1
	fi
done

echo "Asset tag is \"$assetTag\""

# run policies
while IFS= read -r aPolicy
do
	policy=$( echo "$aPolicy" | /usr/bin/awk -F "," '{ print $1 }' )
	trigger=$( echo "$aPolicy" | /usr/bin/awk -F "," '{ print $2 }' )
	"$jamfHelper" -windowType fs -heading "Preparing your Mac" -description "$policy..." -icon /System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns &
	/usr/local/bin/jamf policy -event "$trigger"
	logresult "Success: $policy" "Fail: $policy"
done <<< "$policyList"

# update inventory and asset tag
/usr/local/bin/jamf recon -assetTag "$assetTag"
logresult "Updating inventory and asset tag." "Failed updating inventory and asset tag."

# restart the Mac
"$jamfHelper" -windowType fs -heading "Preparing your Mac" -description "Restarting your Mac..." -icon /System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns &
/sbin/shutdown -r +1 &
logresult "Restarting computer." "Failed restarting computer."

exit 0