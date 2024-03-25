# JamfDeptUploader
 Uploads departments through the Jamf API

To start it, you just need to send the script name and a filename. The file should be a plain text file list of departments, each on its own line. So, like this: jamfDeptUploader departments.txt. It'll prompt for other info it needs.

Starting it with no filenames shows more detailed info: 

Usage
    jamfDeptUploader.sh [-v] [-s <server name>] [-u <client id>] [-p <client secret>] <file name>

Uploads a list of departments to a Jamf Pro server through its API.

Uses API keys which can be set up through the Jamf Pro server (curently under Settings -> System -> API Roles and Clients). The role assigned to the API client ID must have access to create and read Departments or else the Jamf Pro server will return an error. If the server name and/or credentials are not specified, the script will prompt for them.

Options
    -s <server name>
        Specify the server name (URL) of the Jamf Pro server
    -u <client id>
        Specify the client ID for the Jamf Pro server API
    -p <client secret>
        Specify the client secret for the Jamf Pro server API
    -v
        Sets verbose (debug) mode
