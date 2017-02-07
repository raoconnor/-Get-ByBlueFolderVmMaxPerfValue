
<#
.Description	
	Pull metrics over a certian value from Virtual Machines and is designed to be redirected to an output .csv file.
	reports the maximum activity of each VM in a folder during the specified period.
	russ 2015
	

Acknowledgement:  
	Jason Coleman - http://virtuallyjason.blogger.com


Options
 -Stat
 -Days <# of days to attempt to read>


Note 
 Memory Active, which is a level 2 statistic may not be available. 

#>


[CmdletBinding()]
param (
[alias("v")]
[string]$VM = "",
[alias("d")]
[int]$Days = 4,
[alias("t")]
[int]$Threshold = 10,
[alias("s")]
[string]$Stat = $(read-host -Prompt "Enter the Stat that you wish to analyze (cpuReady | cpuMax | memMax ):")
)
	



# Identify the containing folder and add to variable
Get-folder | Where {$_.Type -eq "VM"} | Select Name

$foldername = Read-host "please enter foldername"
$f = Get-Folder $foldername
$folder = (Get-Folder $f | Get-View)
Write-host "Folder =" $folder.Name  "`n" -ForegroundColor White 

# Collect vms the in blue folder
$vmnames = Get-View -SearchRoot $folder.MoRef -ViewType "VirtualMachine" | Select Name
$VMs = Get-vm $vmnames.name

if ($Stat -eq "cpuReady"){
 $metric = "cpu.ready.summation"
}
elseif ($Stat -eq "cpuMax"){
 $metric = "cpu.usagemhz.average"
 $Stat = "computeMax"
}
elseif ($Stat -eq "memMax"){
 $metric = "mem.active.average"
 $Stat = "computeMax"
}
elseif ($Stat -eq "computeMax"){
 $metric = "cpu.usagemhz.average"
 write-output "Reporting CPU Mhz Usage"
}
else{
}

$start = (Get-Date).AddDays(-$Days)

# Discovers any VMs that have CPU Ready values above the specified threshold.
if ($Stat -eq "cpuReady"){
 write-output "VM Name, Date of Entry, Value"
 foreach ($ThisVM in $VMs){
  if ($ThisVM.PowerState -eq "PoweredOn"){
   foreach ($Report in $(Get-Stat -Entity $ThisVM -Stat $metric -Start $start -Erroraction "silentlycontinue")){
    $ReadyPercentage = (($Report.Value/10)/$Report.IntervalSecs)
    if ($ReadyPercentage -gt $Threshold){
     $PerReadable = "$ReadyPercentage".substring(0,4)
     write-output "$($Report.Entity), $($Report.Timestamp), $PerReadable%"
    }
   }
  }
 }
}

# Compute Max reporting, reports either max CPU Mhz or RAM KB depending on the specified metric
elseif ($Stat -eq "computeMax"){
 write-output "VM Name, Date of Entry, Value"
 foreach ($ThisVM in $VMs){
  $MaxActive = 0
  $DateOfInterest = 0
  foreach ($Report in $(Get-Stat -Entity $ThisVM -Stat $metric -Start $start -Erroraction "silentlycontinue")){
   if ($Report.Value -gt $MaxActive){
    $MaxActive = $Report.Value
    $DateOfInterest = $Report.Timestamp
   }
  }
  write-output "$ThisVM, $DateOfInterest, $MaxActive"
 }
}
# Memory swap/balloon detection; largely untested.
elseif ($Stat -eq "memProblem"){
 write-output "VM Name, Date of Entry, Value"
 foreach ($ThisVM in $VMs){
  foreach ($Report in $(Get-Stat -Entity $ThisVM -Stat mem.vmmemctl.average -Start $start -Erroraction "silentlycontinue")){
   if ($Report.value -gt 0){
    write-output "$($Report.Entity), $($Report.Timestamp), $($Report.Value) KB Balloon"
    #write swap rates at that time.  Figure out how to target the specific timeframe.
    $SwapIn = get-stat -entity $ThisVM -stat "mem.swapinrate.average" -start $report.Timestamp -finish $Report.Timestamp -erroraction "silentlycontinue"
    write-output "$($Report.Entity), $($Report.Timestamp), $($SwapIn.Value) KBps Swap In"
    $SwapOut = get-stat -entity $ThisVM -stat "mem.swapoutrate.average" -start $report.Timestamp -finish $Report.Timestamp -erroraction "silentlycontinue"
    write-output "$($Report.Entity), $($Report.Timestamp), $($SwapIn.Value) KBps Swap Out"
   }
  }
 }
}
else{
 write-output "please use a supported Stat"
}