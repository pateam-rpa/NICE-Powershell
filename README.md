# NICE-Powershell
Powershell scripts to support the infrastructure and or maintenance tasks for NICE
This repository will hold multiple Powershell scripts.

## Scripts:

### Invoke-Task.ps1
This script is ment to give more granular scheduling capabilities than existing in the product. 
As examples:
* Schedule a task from Monday - Friday between 9:00-20:00, running every 5 minutes
And Saturday from 9:00-17:00, running every 10 minutes.
or
* Schedule a task to run once every 4 hours, except between 22:00-02:00

If you want, there is a example xml that can be imported into the windows task scheduler. 

In addition, this script will check if there currently is an identical task in the Queue(Elastic Search) already or beeing processed by a bot.
If that is the case, the powershell will not invoke another one, preventing two robots working on the same, e.g. reading emails or getting records from a DB.


### Invoke-Task-Volume.ps1

This is a Powershell used on the NICE App server to schedule triggering of automations in a more granular way than possible with the Automation Portal
The script is identical to Invoke-Task.ps1 with the addition that it passes on 1 parameter for a robotic workflow, which is the number of iterations the bot should do.
This allows to e.g. during daytime or weekdays pick up more tasks with each run than otherwise. 

### Unblock-Folder.ps1

A simple powershell to 'unblock' files before running the RTServer setup, make sure to run this file before starting the install, else strange errors can happen during installation.
Just run and select the directory that holds the setup files.

## Requirements:
- None, powershell is supported by default in windows

## Install:
- See Wiki for detailed explainations.

## Verified Compatibility:

Not compatible with 6.x or older (due to microservice redesign)
- NICE APA 7.0
- NICE APA 7.1
- NICE APA 7.2


Disclaimer: this is a product of PAteam meant for the NICE community and is not created or supported by NICE