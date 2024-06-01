[CmdletBinding()]
Param(

  [Parameter(Mandatory=$false)]
  [string]  
  $SCOMManagementServer,

  [Parameter(Mandatory=$false)]
  [string]$ClassName
  )



<#
Test values 

$SCOMManagementServer = "."
$ClassName = "Linux.Agent.Maintenance.Mode.AgentMaintenanceMode.Class" # valid class name
#$ClassName = "Broken.class" #invalid class 

#>


$ScriptName = "Stop-MMForAllInstancesOfClass.ps1"
$EventNumber = 5001

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

AppendLog ("Getting Class $ClassName")
Write-Verbose $Script:CurrentAction
$Class = Get-SCOMClass -Name $ClassName
if($Class){
    AppendLog ("Class found '$($Class.Displayname)'")
    Write-Verbose $Script:Trace

    AppendLog ("Getting instances in maintenance mode")
    Write-Verbose $Script:Trace
    $Instances = @(Get-SCOMClassInstance -Class $Class | ? {$_.InMaintenanceMode})
    if($Instances){
        AppendLog ("$($Instances.Count) instances found in maintenance mode")
        Write-Verbose $Script:Trace

        foreach($Instance in $Instances){
            AppendLog ("Stopping maintenance mode for $($Instance.DisplayName) on $($Instance.Path)")
            Write-Verbose $Script:Trace
            $Instance.StopMaintenanceMode([System.DateTime]::Now.ToUniversalTime(),[Microsoft.EnterpriseManagement.Common.TraversalDepth]::Recursive)
        }   
    }else{
        AppendLog ("No instances found in maintenance mode")
        Write-Verbose $Script:Trace
    }
}else{
    AppendLog ("Class not found")
    Write-Verbose $Script:Trace
}

AppendLog ("Script completed")
Write-Verbose $Script:Trace
$api.LogScriptEvent($ScriptName,$EventNumber,4, $Script:Trace)



