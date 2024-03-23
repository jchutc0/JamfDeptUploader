#!/bin/bash

# default values
#### #### #### #### #### #### #### #### #### #### 
declare scriptname=$(basename "$0")
declare client_id
declare client_secret
declare servername
declare token

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
exit_with_error() {
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
	echo "    ${scriptname} [-v] [-s <server name>] [-u <client id>] [-p <client secret>] <file name>..."
	echo ""
	echo "Uploads one or more files to a Jamf Pro server through its API. Supports multiple files and wildcards."
	echo ""
	echo "Uses API keys which can be set up through the Jamf Pro server (curently under Settings -> System -> API Roles and Clients). The role assigned to the API client ID must have access to to the proper operation or else the Jamf Pro server will send an error. If the server name and/or credentials are not specified, the script will prompt for them."
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
	exit_with_error "ERROR: $1"
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

## requestToken
#### #### #### #### #### #### #### #### #### #### 
# requests an API token from the Jamf server
requestToken() {
	local webdata
	if checkToken; then return; fi
	debug "Getting new token"
	if ! webdata=$(curl -s --request POST "${servername}/api/oauth/token" \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "grant_type=client_credentials" \
        --data-urlencode "client_id=${client_id}" \
        --data-urlencode "client_secret=${client_secret}"); then
		debug "Connection error. Exiting."
		echo "Detail: ${webdata}"
		exit_with_error "Unable to connect to server. See detail above."
    fi
	if ! token=$(printf "%s" "${webdata}" | /usr/bin/plutil -extract "access_token" raw -o - -); then
		debug "Token data error. Exiting."
		echo "Server response: ${webdata}"
		exit_with_error "Unable to extract token data"
	fi
	if ! checkToken; then 
		debug "Token validation error. Exiting."
		echo "Server response: ${webdata}"
		exit_with_error "Unable to get token data"
	fi
	debug "Bearer Token: $token"
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

# TODO: Check readability of file
# TODO: Process file - translate to URL encode, sort, unique. exclude null department
# TODO: Get an API token
requestToken
# TODO: Download current list of departments through API
# TODO: For each new department
# TODO: If department not in list
# TODO: Upload encoded department through API

debug "Hello, there!"