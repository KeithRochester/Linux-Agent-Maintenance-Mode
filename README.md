# Linux Agent Maintenance Mode MP

## MP and Visual Studio Files
* [Download MP](MPS/Linux.Agent.Maintenance.Mode.mp)
* [Visual Studio Solution File](Linux%20Agent%20Maintenance%20Mode/)

## Introduction

Management Pack used to start, extend, or stop maintenance mode for a Unix/Linux computer from the agent.

Maintenance mode is controled by writing entries to a log file (**/var/log/scom-agentmm.log**) on the agent.   

## Log File Entries

The log file entries must follow a set format. 

**Starting/Extending Maintenance Mode**

#TIMESTAMP#,START,#DURATION#,#COMMENT#,#REASON#

### _Valid Maintenance Mode Reasons_

* ApplicationInstallation
* ApplicationUnresponsive
* LossOfNetworkConnectivity
* PlannedApplicationMaintenance
* PlannedHardwareInstallation
* PlannedOperatingSystemReconfiguration
* PlannedOther
* SecurityIssue
* UnplannedApplicationMaintenance
* UnplannedHardwareMaintenance
* UnplannedOther

### _Example_
>01/06/2024 06:30,START,60,Testing MM,PlannedApplicationMaintenance

**Stopping Maintenance Mode**

#TIMESTAMP#,STOP

### _Example_
>01/06/2024 06:30,STOP
