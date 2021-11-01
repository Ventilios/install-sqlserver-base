<#

    .SYNOPSIS
    Helper functions for SQL Server installation script. 


    .DESCRIPTION
    Contains a set of reusable Functions that are needed in the SQL Server installation script. 
 
#>

#
# Get the current location of where the scripts was executed
Function Get-ScriptDirectory {
  $invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $invocation.MyCommand.Path
}

#
# Pause the current process and wait for confirmation
Function pause ($message) {
    # Check if running script with Powershell ISE
    if ($psISE)
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$message")
    } else {
        Write-Host "$message" -ForegroundColor Yellow
        $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

#
# Verify file path by checking if the variable contains data and if the path actually exists
Function Invoke-VerifyPath {
    Param (  
        [string]$filepath
    )  
    
    if([String]::IsNullOrEmpty($filepath)) {
        Write-Host "Invoke-VerifyPath - Filepath variable is null or empty." -Foreground Red
        return $false
    }

    if(-Not(Test-Path -Path $filepath )) {
        
        Write-Host "Path $filepath not found." -Foreground Red
        return $false
    }

    return $true
}
