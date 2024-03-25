#!/bin/bash

# default values
#### #### #### #### #### #### #### #### #### #### 
declare scriptname=$(basename "$0")
declare client_id
declare client_secret
declare servername
declare token
declare -a userDepts
declare jamfDepts

## debug
#### #### #### #### #### #### #### #### #### #### 
# $1 = message to print
# scriptname - basename of the script
# debug_mode - set (true) if script sends debug messages
debug() {
	if [ -z "${debug_mode+x}" ]; then return; fi
	local timestamp=$(date +%Y-%m-%d\ %H:%M:%S)    
	echo "${timestamp} [${scriptname}]:  $@" 1>&2
}

## usage
#### #### #### #### #### #### #### #### #### #### 
# Exits the program with an error message
exitWithError() {
	local error_message="$1"
	debug "[ERROR] ${error_message}"
	echo "${error_message}" 1>&2
	exit 1
}

## usage
#### #### #### #### #### #### #### #### #### #### 
# prints the program usage
usage() {
	echo "Usage"
	echo "    ${scriptname} [-v] [-s <server name>] [-u <client id>] [-p <client secret>] <file name>"
	echo ""
	echo "Uploads a list of departments to a Jamf Pro server through its API."
	echo ""
	echo "Uses API keys which can be set up through the Jamf Pro server (curently under Settings -> System -> API Roles and Clients). The role assigned to the API client ID must have access to create and read Departments or else the Jamf Pro server will return an error. If the server name and/or credentials are not specified, the script will prompt for them."
	echo ""
	echo "Options"
	echo "    -s <server name>"
	echo "        Specify the server name (URL) of the Jamf Pro server"
	echo "    -u <client id>"
	echo "        Specify the client ID for the Jamf Pro server API"
	echo "    -p <client secret>"
	echo "        Specify the client secret for the Jamf Pro server API"
	echo "    -v"
	echo "        Sets verbose (debug) mode"
}

## usageError
#### #### #### #### #### #### #### #### #### #### 
# prints an error showing the program usage
usageError() {
	usage 
	echo ""
	exitWithError "ERROR: $1"
}

## checkToken
#### #### #### #### #### #### #### #### #### #### 
# checks for a valid token
checkToken() {
	debug "Checking token..."
	if [ -n "${token}" ]; then
		debug "    Valid token"
		return 0
	fi
	debug "    Invalid token"
	return 1
}

## processFile
#### #### #### #### #### #### #### #### #### #### 
# processes file of departments
processFile() {
	debug "  Checking readability of file"
	if [ ! -r "$1" ]; then
		exitWithError "Cannot read from file $1"
	fi

	debug "---"
	debug "Starting departments file:"
	if [ -n "${debug_mode+x}" ]; then cat "$1"; fi
	debug "---"
	

	debug "Processed departments file:"
	# https://stackoverflow.com/questions/11393817/read-lines-from-a-file-into-a-bash-array
	# https://stackoverflow.com/questions/3432555/remove-blank-lines-with-grep
	IFS=$'\r\n' \
	GLOBIGNORE='*' \
	command eval 'userDepts=($(sort "$1" | uniq | grep -vi "null"))'
	for i in "${userDepts[@]}"; do
		debug "$i"		
	done
	debug "---"
	
	debug "Evaluating array length for ${#userDepts[@]}"
	if [ ${#userDepts[@]} -eq 0 ]; then
		exitWithError "No valid items in departments file!"
	fi

}

## requestToken
#### #### #### #### #### #### #### #### #### #### 
# requests an API token from the Jamf server
requestToken() {
	local webdata
	if checkToken; then return; fi
	debug "Getting new token"
	local tokenUrl="${servername}/api/oauth/token"
	debug "  Using URL $tokenUrl"
	if ! webdata=$(curl -s --request POST "$tokenUrl" \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "grant_type=client_credentials" \
        --data-urlencode "client_id=${client_id}" \
        --data-urlencode "client_secret=${client_secret}"); then
		debug "Connection error. Exiting."
		echo "Detail: ${webdata}"
		exitWithError "Unable to connect to server. See detail above."
    fi
	if ! token=$(printf "%s" "${webdata}" | /usr/bin/plutil -extract "access_token" raw -o - -); then
		debug "Token data error. Exiting."
		echo "Server response: ${webdata}"
		exitWithError "Unable to extract token data"
	fi
	if ! checkToken; then 
		debug "Token validation error. Exiting."
		echo "Server response: ${webdata}"
		exitWithError "Unable to get token data"
	fi
	debug "Bearer Token: $token"
}

## getDeptList
#### #### #### #### #### #### #### #### #### #### 
# Download current list of departments through API
getDeptList() {
	local deptUrl="${servername}/JSSResource/departments"
	local webdata
	requestToken
	debug "  using URL $deptUrl"
	if ! webdata=$(curl -s --request GET "$deptUrl" \
		-H "Authorization: Bearer $token" \
		-H 'accept: application/json'); then
		debug "Connection error. Exiting."
		echo "Detail: ${webdata}"
		exitWithError "Unable to get department data. See detail above."
	fi
	if ! jamfDepts=$(printf "%s" "${webdata}" | /usr/bin/plutil -extract "departments" json -o - -); then
		debug "Department data error. Exiting."
		echo "Server response: ${webdata}"
		exitWithError "Unable to extract department data"
	fi
	debug "Jamf Departmnet List:"
	debug "$jamfDepts"
}

## apiUpload
#### #### #### #### #### #### #### #### #### #### 
# Upload a department through the API
apiUpload() {
	debug "Uploading Department $1"
	local postUrl="${servername}/JSSResource/departments/id/0"
	xml="<department><name>$1</name></department>"
	debug " using URL $postUrl"
	if ! webdata=$(curl -s --request POST "$postUrl" \
		-H "Authorization: Bearer $token" \
		-H "Content-Type: application/xml" \
		-d "$xml"); then
		debug "Connection error. Exiting."
		echo "Detail: ${webdata}"
		exitWithError "Unable to get department data. See detail above."
	fi
	debug "Data sent successfully"
}

## processDeptList
#### #### #### #### #### #### #### #### #### #### 
# Process list of departments
processDeptList() {
	local uploadCount=0
	
	for i in "${userDepts[@]}"; do
		debug " Examining item $i"
		## TODO: Add quotation marks at the beginning and end of the string
		local escapedDept=$(printf "%s" "$i" | sed 's/\"/\\\\\"/g')
		escapedDept="\"$escapedDept\""
		debug "  escaped: $escapedDept"
		if echo "$jamfDepts" | grep "$escapedDept" &>/dev/null; then
			debug "  Department exists"
		else
			debug "  Department does not exist"
			apiUpload "$i"
			uploadCount=$((uploadCount+1))
		fi
	done
	echo "Updated $uploadCount item(s)"
}


## main
#### #### #### #### #### #### #### #### #### #### 
echo "$scriptname"

# Parse arguments
while getopts "hp:s:u:v" flag
do
	case "${flag}" in
		h) usage && exit 0;;
		p) client_secret="${OPTARG}";;
		s) servername="${OPTARG}";;
		u) client_id="${OPTARG}";;
		v) debug_mode=true;;
		:) usageError "-${OPTARG} requires an argument.";;
		?) usage && exit 0;;
	esac
done
## Remove the options from the parameter list
debug "Argument List:"
debug "$@"
shift $((OPTIND-1))
if [ ${#} -eq 0 ]; then
	usageError "Specify one or more files to process."
fi

debug "Checking for server name"
while [ -z "${servername}" ]; do
	read -r -p "Please enter the URL to the Jamf Pro server (starting with https): " servername
done

debug "Checking for client_id"
while [ -z "${client_id}" ]; do
	read -r -p "Please enter a Jamf API client ID: " client_id
done

debug "Checking for client_secret"
while [ -z "${client_secret}" ]; do
	read -r -s -p "Please enter a Jamf API client secret: " client_secret
	echo ""
done

debug "Processing department file"
processFile "$1"

debug "Getting Jamf departments list"
getDeptList

debug "Processessing department list"
processDeptList

debug "Exiting."