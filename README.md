# Description
PowerShell script to deploy a single SQL Server instance. Uses some dynamic parameters to quickly deploy a test environment from a folder structure. Simple script for testing purposes only.

# Requirements
1. Based on the below folder and content structure. Be sure to modify the paramater _ValidateSet_: $sqlversionScripts, $sqledition, $sqlenvironment.
2. Be sure to change the parameter $sqlserveradmin to an account that suits your environment. 
3. Invoke-Sqlcmd is used to execute SQL Scripts. Script contains a check to review if the function is available, if not it will do a fallback to the _Tools\sqlserver_ folder. See paragraph Invoke-Sqlcmd for additional notes. 

# Folder and content requirements
Folder and file structure needs to be followed. Expects the following folder structure within a folder (sourcedirectory):
* [Version] - Distinct SQL Server Version for example 2012 or 2019. This folder needs the following content for each Version-folder.
  * _ConfigurationFile-MSQ-$sqlenvironment-$sqlversion.ini_ - For example: ConfigurationFile-MSQ-DEV-2019.ini
  * _Configure-SqlServer$sqlversion-$sqlenvironment-Base.sql_ - For example: Configure-SqlServer2019-DEV-Base.sql
  * _SQLServerInstallationImage.iso_ - For example: SQLServer2019-x64-ENU-Dev.iso
* [Tools] - SQL Server Management Studio setup and or SqlServer PowerShell module content in sqlserver-folder.
* [Functions] - Contains helper functions for the installation script: Get-IniContent.ps1 and Install-HelperFunctions.ps1. 
* [Root of the folder] - Will contain Install-SqlServer-Base.ps1 file and log-files will be written into this folder. 

# Options to get Invoke-Sqlcmd working
Online install: Install-Package -module sqlserver
Options to use offline - [Download .nupkg from a Microsoft source](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver15):
1. Install using Nuget offline procedures. For example: https://nmanzi.com/blog/installing-nupkg-offline/
2. Without installation: Rename the .nupkg to .zip, copy the module to the PowerShell modules directory and load it with Import-Module. For example: https://docs.datprof.com/knowledgebase/how-to-install-microsoft-powershell-sqlserver-module
3. _Script will fallback to this option._ Without installation: rename the .nupkg to .zip and extract the content the TOOLS directory in a directory name _sqlservermodule_
