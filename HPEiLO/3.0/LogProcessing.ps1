﻿####################################################################
#Get Event Log details from iLO
####################################################################

<#
.Synopsis
    This Script gets the log Information.
	
.DESCRIPTION
    This Script gets Event Log and IML log information.
	
	The cmdlets used from HPEiLOCmdlets module in the script are as stated below:
	Enable-HPEiLOLog, Connect-HPEiLO, Get-HPEiLOIML, Get-HPEiLOEventLog, Disconnect-HPEiLO, Disable-HPEiLOLog

.EXAMPLE
    
    PS C:\HPEiLOCmdlets\Samples\> LogProcessing.ps1
	
    This script does not take any parameter.
 
.INPUTS
	iLOInput.csv file in the script folder location having iLO IPv4 address, iLO Username and iLO Password.

.OUTPUTS
    None (by default)

.NOTES
	Always run the PowerShell in administrator mode to execute the script.
	
    Company : Hewlett Packard Enterprise
    Version : 3.0.0.0
    Date    : 01/15/2020 

.LINK
    http://www.hpe.com/servers/powershell
#>

try
{
    $path = Split-Path -Parent $PSCommandPath
    $path = join-Path $path "\iLOInput.csv"
    $inputcsv = Import-Csv $path
	if($inputcsv.IP.count -eq $inputcsv.Username.count -eq $inputcsv.Password.count -eq 0)
	{
		Write-Host "Provide values for IP, Username and Password columns in the iLOInput.csv file and try again."
        exit
	}

    $notNullIP = $inputcsv.IP | Where-Object {-Not [string]::IsNullOrWhiteSpace($_)}
    $notNullUsername = $inputcsv.Username | Where-Object {-Not [string]::IsNullOrWhiteSpace($_)}
    $notNullPassword = $inputcsv.Password | Where-Object {-Not [string]::IsNullOrWhiteSpace($_)}
	if(-Not($notNullIP.Count -eq $notNullUsername.Count -eq $notNullPassword.Count))
	{
        Write-Host "Provide equal number of values for IP, Username and Password columns in the iLOInput.csv file and try again."
        exit
	}
}
catch
{
    Write-Host "iLOInput.csv file import failed. Please check the file path of the iLOInput.csv file and try again."
    Write-Host "iLOInput.csv file path: $path"
    exit
}

Clear-Host

# script execution started
Write-Host "****** Script execution started ******`n" -ForegroundColor Yellow
#Decribe what script does to the user

Write-Host "This script gets the Event log and IML log information.`n"

#Load HPEiLOCmdlets module
$InstalledModule = Get-Module
$ModuleNames = $InstalledModule.Name

if(-not($ModuleNames -like "HPEiLOCmdlets"))
{
    Write-Host "Loading module :  HPEiLOCmdlets"
    Import-Module HPEiLOCmdlets
    if(($(Get-Module -Name "HPEiLOCmdlets")  -eq $null))
    {
        Write-Host ""
        Write-Host "HPEiLOCmdlets module cannot be loaded. Please fix the problem and try again"
        Write-Host ""
        Write-Host "Exit..."
        exit
    }
}
else
{
    $InstallediLOModule  =  Get-Module -Name "HPEiLOCmdlets"
    Write-Host "HPEiLOCmdlets Module Version : $($InstallediLOModule.Version) is installed on your machine."
    Write-host ""
}

	$Error.Clear()
	#Enable logging feature
	Write-Host "Enabling logging feature" -ForegroundColor Green
	$log = Enable-HPEiLOLog
	$log | fl
	
if($Error.Count -ne 0)
{ 
	Write-Host "`nPlease launch the PowerShell in administrator mode and run the script again." -ForegroundColor Yellow 
	Write-Host "`n****** Script execution terminated ******" -ForegroundColor Red 
	exit 
}	

try
{
	
	$ErrorActionPreference = "SilentlyContinue"
	$WarningPreference ="SilentlyContinue"
	
    $connection = Connect-HPEiLO -IP $inputcsv.IP -Username $inputcsv.Username -Password $inputcsv.Password -DisableCertificateAuthentication

	$Error.Clear()
	
	if($Connection -eq $null)
    {
        Write-Host "`nConnection could not be established to any target iLO.`n" -ForegroundColor Red
        $inputcsv.IP | fl
        exit;
    }
	
	#List of IP's that could not be connected
	if($Connection.count -ne $inputcsv.IP.count)
    {
        Write-Host "`nConnection failed for below set of targets" -ForegroundColor Red
        foreach($item in $inputcsv.IP)
        {
            if($Connection.IP -notcontains $item)
            {
                $item | fl
            }
        }
    }

    if($connection -ne $null)
    {

        Write-Host "`nGetting IML Entry information." -ForegroundColor Green

        $result = Get-HPEiLOIML -Connection $connection 

        foreach($output in $result)
        {

            if($output.Status -eq "OK")
            {
                Write-Host "`nProcessing IML log information for $($output.IP)." -ForegroundColor Green

                Write-Host "`n$($output.IP) has $($output.IMLLog.Count) IML entries." -ForegroundColor Cyan
                $sevs = $(foreach ($event in $output.IMLLog) {$event.Severity})
                $uniqsev = $($sevs | Sort-Object | Get-Unique)
                $sevcnts = $output.IMLLog | group-object -property Severity –noelement
                Write-Host "There are $($uniqsev.Count) type(s) of events in the IML." -ForegroundColor Cyan
                $sevcnts | Format-Table
                $message = $(foreach ($event in $output.IMLLog) {if($event.Severity -eq "Critical") {$event.Message}})
                $uniqmessage = $($message | Sort-Object | Get-Unique)
                if($uniqmessage -ne $null)
                {
                    $allMessage = [string]::Join("`n",$uniqmessage)
                    Write-Host "The critical entry description are: `n$allMessage" -ForegroundColor Cyan
                }
          
            }
            
            else
            {
                if($output.StatusInfo -ne $null)
                {   $message = $output.StatusInfo.Message; Write-Host "`nFailed to get IML log information: "$message -ForegroundColor Red }
            }

        }

        
        Write-Host "`nGetting Event Log Entry information." -ForegroundColor Green

        $result = Get-HPEiLOEventLog -Connection $connection 

        foreach($output in $result)
        {

            if($output.Status -eq "OK")
            {
                Write-Host "`nProcessing Event log information for $($output.IP)." -ForegroundColor Green

                Write-Host "`n$($output.IP) has $($output.EventLog.Count) log entries." -ForegroundColor Cyan
                $sevs = $(foreach ($event in $output.EventLog) {$event.Severity})
                $uniqsev = $($sevs | Sort-Object | Get-Unique)
                $sevcnts = $output.EventLog | group-object -property Severity –noelement
                Write-Host "There are $($uniqsev.Count) type(s) of events in the Event Log." -ForegroundColor Cyan
                $sevcnts | Format-Table
                $message = $(foreach ($event in $output.EventLog) {if($event.Severity -eq "Critical") {$event.Message}})
                $uniqmessage = $($message | Sort-Object | Get-Unique)
                if($uniqmessage -ne $null)
                {
                    $allMessage = [string]::Join("`n",$uniqmessage)
                    Write-Host "The critical entry description are: `n$allMessage" -ForegroundColor Cyan
                }
          
            }
            
            else
            {
                if($output.StatusInfo -ne $null)
                {   $message = $output.StatusInfo.Message; Write-Host "`nFailed to get Event log information: "$message -ForegroundColor Red }
            }

        }       
    }
    else
    {
        Write-Host "`nThe given list of IP's are not reachable" -ForegroundColor Red
    }
 }
 catch
 {
 }
finally
{
    if($connection -ne $null)
    {
        #Disconnect 
		Write-Host "Disconnect using Disconnect-HPEiLO `n" -ForegroundColor Yellow
		$disconnect = Disconnect-HPEiLO -Connection $Connection
		$disconnect | fl
		Write-Host "All connections disconnected successfully.`n"
    }  
	
	#Disable logging feature
	Write-Host "Disabling logging feature`n" -ForegroundColor Yellow
	$log = Disable-HPEiLOLog
	$log | fl
	
	if($Error.Count -ne 0 )
    {
        Write-Host "`nScript executed with few errors. Check the log files for more information.`n" -ForegroundColor Red
    }
	
    Write-Host "`n****** Script execution completed ******" -ForegroundColor Yellow
}