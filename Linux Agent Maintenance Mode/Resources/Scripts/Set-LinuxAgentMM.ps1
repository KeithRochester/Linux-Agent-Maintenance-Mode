[CmdletBinding()]
Param(

  [Parameter(Mandatory=$false)]
  [string]  
  $SCOMManagementServer,

  [Parameter(Mandatory=$false)]
  [string]$id,

  [Parameter(Mandatory=$false)]
  [string]$MMEvent,

  [Parameter(Mandatory=$false)]
  [string]$Separator
  )



<#
Test values 

$id = "00000000-0000-0000-0000-000000000000"
$SCOMManagementServer = "."
$MMEvent = "19/10/2022 14:30,START,60,Testing MM,PlannedApplicationMaintenance" #Start
$MMEvent = "19/10/2022 14:30,STOP" #Stop
$Separator = ","
#>
$Action = $MMEvent.split($Separator)[1]


<# Valid MM Reasons
“ApplicationInstallation",
"ApplicationUnresponsive",
"LossOfNetworkConnectivity",
"PlannedApplicationMaintenance",
"PlannedHardwareInstallation",
"PlannedOperatingSystemReconfiguration",
"PlannedOther",
"SecurityIssue",
"UnplannedApplicationMaintenance",
"UnplannedHardwareMaintenance",
"UnplannedOther”
#>


$EventNumber = 5002
$ScriptName = "Set-LinuxAgentMM.ps1"

#Setting Trace log varriables to empty
$Script:CurrentAction = ""
$Script:Trace = ""

# Define 'Appendlog' function to allow appending to trace log 
function appendlog ([string]$Message)
{
	
    $Script:CurrentAction = $Message
	$Script:Trace += ((Get-Date).ToString() + "`t" + $Message + " `r`n")
    
    While(($Script:Trace.length) -gt 31000)
    {
       [System.Collections.ArrayList]$TraceList = $Script:Trace.Split("`n")
       $TraceList.Removeat(0)
       $TraceList[0] = "Message has been truncated to fit into Windows Event Log message"
       $Script:Trace = $TraceList -join "`n"
    }
}


$api = New-Object -comObject 'MOM.ScriptAPI'
AppendLog ("Starting script")
Write-Verbose $Script:CurrentAction
$api.LogScriptEvent($ScriptName,$EventNumber,4, $CurrentAction)

AppendLog ("Loading Operations Manager Module and connecting to Management Server: " + $SCOMManagementServer ) 
Write-Verbose $Script:CurrentAction 
Add-PSSnapin Microsoft.EnterpriseManagement.OperationsManager.Client
try{
    New-SCOMManagementGroupConnection -ComputerName $SCOMManagementServer
}
Catch{
    AppendLog ("Could not connect to Management Server " + $SCOMManagementServer  + " exiting script")
    $api.LogScriptEvent($ScriptName,$EventNumber,1, $CurrentAction)
    Write-Error $Script:CurrentAction
    Exit
}





AppendLog ("Getting MM class instance: $id") 
Write-Verbose $Script:CurrentAction 
$UnixComputerClass = Get-SCOMClass -Name 'Microsoft.Unix.Computer'
$MMAgent = Get-SCOMClassInstance -Id $id
$Computer = $MMAgent.GetParentMonitoringObjects() | ? {$_.LeastDerivedNonAbstractManagementPackClassId -eq $UnixComputerClass.Id}



Switch ($Action){

    "START" {

        $MMDuration = $MMEvent.split($Separator)[2]
        $MMComment = $MMEvent.split($Separator)[3]
        $MMReason = $MMEvent.split($Separator)[4]
        $StartDate = $(Get-Date).ToUniversalTime();
        $MMEndDate = $StartDate.AddMinutes($MMDuration)

        if($Computer.InMaintenanceMode){
            AppendLog ("Computer already in Maintenance Mode") 
            Write-Verbose $Script:CurrentAction 
            $CurrentMMEndTime = $Computer.GetMaintenanceWindow().ScheduledEndTime
            $DateDiffScheduledEnd = New-TimeSpan $MMEndDate $CurrentMMEndTime
            if ($DateDiffScheduledEnd.TotalMinutes -lt 0){
                AppendLog ("Extending Maintenance Mode") 
                Write-Verbose $Script:CurrentAction 
                $MMComment = $Computer.GetMaintenanceWindow().Comments + "`r`nExtended: " + $MMComment
                $Computer.UpdateMaintenanceMode($MMEndDate, $Computer.GetMaintenanceWindow().Reason, $MMComment)
                if($MMAgent.InMaintenanceMode){
                    $MMAgent.StopMaintenanceMode([DateTime]::Now.ToUniversalTime(),[Microsoft.EnterpriseManagement.Common.TraversalDepth]::OneLevel);
                }
            }else{
                AppendLog ("Existing Maintenance Mode does not need to be extended") 
                Write-Verbose $Script:CurrentAction 
            }
                               
        }else{
            AppendLog ("Starting Maintenance Mode") 
            Write-Verbose $Script:CurrentAction 
            Start-SCOMMaintenanceMode -Instance $Computer -EndTime ($MMEndDate.ToUniversalTime()) -Comment $MMComment -Reason $MMReason
            $MMAgent.StopMaintenanceMode([DateTime]::Now.ToUniversalTime(),[Microsoft.EnterpriseManagement.Common.TraversalDepth]::OneLevel);
        }    
    }
    "STOP" {
        AppendLog ("Stopping Maintenance Mode") 
        Write-Verbose $Script:CurrentAction 
        $Computer.StopMaintenanceMode([System.DateTime]::Now.ToUniversalTime(),[Microsoft.EnterpriseManagement.Common.TraversalDepth]::Recursive);
    }

}


AppendLog ("Script completed")
Write-Verbose $Script:Trace
$api.LogScriptEvent($ScriptName,$EventNumber,4, $Script:Trace)

