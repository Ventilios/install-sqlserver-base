#Requires -version 5
#Requires -RunAsAdministrator
#Requires -Modules ServerManager, NetSecurity
<#

    .SYNOPSIS
    Deploy a single SQL Server instance sample deployment script.


    .DESCRIPTION
    This scripts delivers the ability to deploy a standalone SQL Server instance 
    with a specific set of configuration parameters.


    .EXAMPLE
    Install-SqlServer-Base -sqlinstancename "TESTINST01" -sqledition "Developer"
    Deploy a named instance of SQL Server.
  
#>
Param(
    # Source directory is a reference to the root directory where all 
    # items for installation are available (Tools, SQL Server versions).
    [string] $sqlsourcedirectory,

    # Version of SQL Server we would like to install
    [ValidateSet(2016,2019)]
    [int] $sqlversion = 2019,

    [ValidateSet('Developer', 'Standard', 'Enterprise')]
    [string] $sqledition = 'Developer',

    [ValidateSet('DEV', 'PROD')]
    [string] $sqlenvironment = 'DEV',

    # Service name. Mandatory, by default MSSQLSERVER
    [ValidateNotNullOrEmpty()]
    [string] $sqlinstancename = 'MSSQLSERVER',
   
    # List of system administrative accounts in the form <domain>\<user>
    # WARNING: Sample contains local administrators as example. Please change!
    [string[]] $sqlserveradmin = @("BUILTIN\Administrators"),

    # Optional: Install Management Studio - Not installed by default.
    [bool] $sqlssmsinstall = $false
)

####
# Start script PowerShell script log
####
$scriptstart = Get-Date
$scriptexecutiondirectory = $PSScriptRoot
Start-Transcript "$scriptexecutiondirectory\Install-SQlServer-$($scriptstart.ToString('s').Replace(':','-')).log"

# 
# Dot source load functions
. (Join-Path ($scriptexecutiondirectory)"\Functions\Get-IniContent.ps1")
. (Join-Path ($scriptexecutiondirectory)"\Functions\Install-HelperFunctions.ps1")

####
# Init -Set Source directory varibale for ISO, SSMS setup and INI-file.
####

#
# Path containing ISO file and INI. 
# When not given as parameter, script path is used. 
if([string]::IsNullOrEmpty($sqlsourcedirectory)) {
    $sqlversiondirectory = (Join-Path ($scriptexecutiondirectory)"Source\$sqlversion\")
    $sqltooldirectory = (Join-Path ($scriptexecutiondirectory)"Source\Tools\")
} else {
    $sqlversiondirectory = (Join-Path ($sqlsourcedirectory)"$sqlversion\")
    $sqltooldirectory = (Join-Path ($sqlsourcedirectory)"Tools\")
}

#
# Verify path
if(-Not(Invoke-VerifyPath($sqlversiondirectory))) {
    Throw "Path of the source directory (base containing all related resources for the script) is not valid. - $sqlsourcedirectory"
}
if(-Not(Invoke-VerifyPath($sqltooldirectory))) {
    Throw "Path of the Tools (ie. SSMS) directory is not available. - $sqltooldirectory"
}

#
# SQL Server ISO file
# Assuming one occurence in the Source\Version directory. 
$sqlisolocation = Get-ChildItem -Path $sqlversiondirectory -filter "*sqlserver$sqlversion*.iso"| Select-Object -ExpandProperty FullName -last 1
if(-Not(Invoke-VerifyPath($sqlisolocation))) {
    Throw "Filepath location for the SQL Server ISO is not valid. - $sqlisolocation"
}

#
# SQL Sever setup INI configuration file
$sqlconfiguration = (Join-Path ($sqlversiondirectory)"\ConfigurationFile-MSQ-$sqlenvironment-$sqlversion.ini")
if(-Not(Invoke-VerifyPath($sqlconfiguration))) {
    Throw "Filepath location for the setup INI-file is not valid. - $sqlconfiguration"
}

#
# SQL Server Management Studio setup location
# Assuming one occurence in the Source\Tools directory.
if($sqlssmsinstall) {
    $ssmssetuplocation = Get-ChildItem -Path $sqltooldirectory -filter "*ssms*.exe"| Select-Object -ExpandProperty FullName -last 1
    if(-Not(Invoke-VerifyPath($ssmssetuplocation))) {
        Throw "Filepath location for SQL Server Management Studio is not valid. - $ssmssetuplocation"
    }
}

####
# Step 0 - Mount SQL Server ISO
####
Write-Host ""
Write-Host "## Step 0 - Mount SQL Server ISO ##" -ForeGroundColor green

#
# Check if it's already mounted
if(!(Get-DiskImage -ImagePath $sqlisolocation).Attached) {
    Mount-DiskImage -ImagePath $sqlisolocation
}

$imagemappeddrive = (Get-DiskImage -ImagePath $sqlisolocation | Get-Volume).DriveLetter
$sqlsetuplocation = ("$($imagemappeddrive):\Setup.exe")

####
# Step 1 - Configure Windows specific settings
####
Write-Host ""
Write-Host "## Step 1 - Configure Windows specific settings ##" -ForeGroundColor green

# 
# Set Windows powerplan to High performance
Try {
    $HighPerf = powercfg -l | ForEach-Object{if($_.contains("High performance")) {$_.split()[3]}}
    $CurrPlan = $(powercfg -getactivescheme).split()[3]
    if ($CurrPlan -ne $HighPerf) {powercfg -setactive $HighPerf}
} Catch {
    Write-Warning -Message "Unable to set power plan to high performance"
}

#
# Set Performance Option “Processor Scheduling” to “Background Services”
Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl -Name Win32PrioritySeparation -Value 18

####
# Step 2 - Check if all drives exist for all specified folders in the INI-file
####
Write-Host ""
Write-Host "## Step 2 - Validate existence of SQL Server related drives ##" -ForeGroundColor green

#
# Sample: Reading from INI and verify if the disks exists where we would like to see SQL Server installed.
$inicontent = Get-IniContent $sqlconfiguration
[string[]] $inifolders = @("INSTANCEDIR", "SQLUSERDBDIR", "SQLUSERDBLOGDIR", "SQLTEMPDBDIR", "SQLBACKUPDIR")

ForEach($inifolder In $inifolders) {
    $inifolderdrive = Split-Path -Path $inicontent["Options"]["$inifolder"].Replace("`"","") -Qualifier
    if(-Not (Test-Path $inifolderdrive)) {
        Write-Host ("Error for INI item {0} - Drive letter does not exists for path: {1}" -f $inifolder, $inicontent["Options"]["$inifolder"]) -ForeGroundColor red
        Write-Host ("Please make sure drive $inifolderdrive is available before starting the installation again.") -ForeGroundColor red
        Exit
    } 
}

####
# Step 3 - Install SQL Server 2016 and SQL Server Management Studio
####
Write-Host ""
Write-Host "### Step 3a - Start installation of SQL Server." -ForeGroundColor green
Write-Host ""

$sqlsetuparguments = "/Q /ConfigurationFile=""$sqlconfiguration"" /SQLSYSADMINACCOUNTS=$sqlserveradmin /INSTANCENAME=$sqlinstancename"
$installationprocess = Start-Process -verb runas -FilePath "$sqlsetuplocation" -ArgumentList $sqlsetuparguments.ToString() -PassThru -Wait
if($installationprocess.ExitCode -eq 0) {
    Write-Host "Installation of SQL Server $sqlversion completed." -ForeGroundColor Green
    Write-Host "Logfile can be found in the Setup Bootstrap\log folder (version dependend 130 for 2016): C:\Program Files\Microsoft SQL Server\" -ForeGroundColor Green
} else {
    Write-Host ("Installation of SQL Server $sqlversion failed! Return code:", $installationprocess.ExitCode) -ForeGroundColor red
    Write-Host "Logfile can be found in the Setup Bootstrap\log folder (version dependend 130 for 2016): C:\Program Files\Microsoft SQL Server\" -ForeGroundColor red
    exit 
}

#
# Install SQL Server Management Studio
if($sqlssmsinstall) {
    Write-Host ""
    Write-Host "### Step 3b - Start installation of SQL Server Management Studio." -ForeGroundColor green
    Write-Host ""
    
    $ssmssetuparguments = "/install /quiet /norestart"
    $ssmsinstallationprocess = Start-Process -verb runas -FilePath "$ssmssetuplocation" -ArgumentList $ssmssetuparguments.ToString() -PassThru -Wait
    if($ssmsinstallationprocess.ExitCode -eq 0) {
        Write-Host "Installation of SQL Server Management Studio completed." -ForeGroundColor Green
        Write-Host ""
    } else {
        Write-Host ("Installation of SQL Server Management Studio failed! Return code:", $ssmsinstallationprocess.ExitCode) -ForeGroundColor Red
        Write-Host ""
    }
}

####
# Step 4 - Apply SQL Server post configuration settings
####

#
# SQL Server was succesfully installed. After proceeding (confirm Y), instance level configuration settings will be applied.
$confirmation = Read-Host "Step 4 - Would you like to proceed applying SQL Server configuration settings? [y/n]"
if ($confirmation -eq 'y') {
    #
    # Sample file format: Configure-SqlServer2019-DEV-Base.sql
    [string]$sqlpostconfigurationfile = (Join-Path (Get-ScriptDirectory)"\Source\$sqlversion\Configure-SqlServer$sqlversion-$sqlenvironment-Base.sql")

    # Build the connection string
    # NOTE: Assumes that we're executing the script on the server where SQL Server is installed.
    $sqlserverconnection = "."
    if($sqlinstancename -ne "MSSQLSERVER") {
        $sqlserverconnection = ".\$sqlinstancename"    
    }

    #
    # First check if Invoke-Sqlcmd is available. When not available, fallback to Tools\sqlserver folder.
    if (-Not(Get-Command -name 'Invoke-Sqlcmd' -errorAction SilentlyContinue)) {
        # Below option is using option 3
        # Check if tools\sqlservermodule directory exists and load the module
        $sqlservermodule = (Join-Path ($sqltooldirectory)"\sqlservermodule\SqlServer.psm1")
        if(Invoke-VerifyPath($sqlservermodule)) {
            Write-Host "SqlServer PowerShell module is not available, falling back to the tools\sqlservermodule directory." -ForegroundColor Green
            Import-Module $sqlservermodule
        } else {
            Write-Host "Missing sqlservermodule! Unable to apply SQL Server settings."-ForegroundColor Red
        }
    }
        
    if (Get-Command -name 'Invoke-Sqlcmd' -errorAction SilentlyContinue) {
        try {
            # Connect to local DEFAULT instance, assumption based on current architecture
            Write-Host "Applying SQL Server Post-Configuration settings to instance: $sqlserverconnection" -ForeGroundColor green
            Invoke-Sqlcmd -ServerInstance $sqlserverconnection -Database master -InputFile $sqlpostconfigurationfile -Verbose
        } catch {
            Write-Host "Unable to apply post configuration settings, please apply manually."-ForegroundColor Red
        }
    } else {
        Write-Host "Unable to apply SQL Server settings. Proceed manually."-ForegroundColor Red
    }
} else {
    Write-Host "Skip applying SQL Server settings."-ForegroundColor Red
}

####
# Step 5 - Cleanup
####

#
# Dismount SQL Server image
if((Get-DiskImage -ImagePath $sqlisolocation).Attached) {
    Dismount-DiskImage -ImagePath $sqlisolocation
}
