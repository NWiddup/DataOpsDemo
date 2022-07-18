# DataOpsDemo
Demo for DataOps solutions with Bicep IAC + SSDT + ADF. Currently the solution is focussed on Bicep IAC, with SSDT + ADF to follow. This solution is based on my working experience with the technologies in customer deployments. FYI:

* **This code is provide as is without warranty.**
* There are **multiple opportunities** for optimisation of this code, it is provided as an intro & sample **ONLY**.

## Refs

* https://docs.microsoft.com/en-us/azure/architecture/checklist/data-ops
* https://docs.microsoft.com/en-us/azure/devops/learn/what-is-devops
* https://github.com/Azure/devops-governance
* Specific Layered protection for your environments & delivery: https://github.com/Azure/devops-governance/blob/main/CONCEPT.md
* FastTrack for Azure team presenting on Infrastructure as Code: https://www.youtube.com/watch?v=p4I9Xfp80ZQ
* Azure Academy series on Infrastructure as Code + DevOps (this is Part 1): https://www.youtube.com/watch?v=hJKnMw5_HzE&ab_channel=AzureAcademy
## PreReqs

### Steps before running prereq script.

**These items are not completed in the prereq script, and will need to be done manually, and ideally before running the prereq script**
- create AAD SQL Admin groups for each environment
- get GUID for AzDO SQL Admin groups
    - consider whether you need to add the GUID for the RG level Service Principals to the AzDO SQL Admins group for the environment. This would allow  administrative actions to be conducted from the AzDO Pipelines by using the relevant service connection
- gather your own Azure Subscription Id's
- update the Bicep templates & pipelines to substitute in your own GUIDS (For the SQL Admin groups and Azure Subscription Id's)

### Running prereq script
The below prerequisite items are almost all handled within the [PreReq-Setup.ps1](.\PreReq-Setup.ps1) PowerShell/AzureCLI Script. They are listed out below so you can confirm you have completed the relevant steps.
- create azure devops org
- create azure devops project
- create service principals in AzDO to run each service connection
- create service connections in your DevOps project for each of your environments (Dev/Test/Prod) using the relevant service principals (or managed identities)
    - If you want to manage permissions within your IAC, your Service Principal will need either Owner permissions (at the RG/Sub level), or a custom role granting it permission to create other authorisations.
    - you may want to consider having 2 service connections, one at the sub level and one at the RG level. You would use the Sub level service connection to complete privileged activities, then the RG level service connection to complete local activities.
    - **Please review the [Refs](#refs) before proceeding**
- create folders for your pipelines in the project
- create the pipelines for your project
- run initial deployment of [Core Infrastructure](.\source\CoreInfrastructure).

### Post running prereq script

You will need to setup Branch Policies (Approvers - minimum 1) on the `main` branch, so that commits cannot be pushed directly to `main` (_Branch Policies Note: If any required policy is enabled, this branch cannot be deleted and changes must be made via pull request._). This will ensure there is opportunity to review the code before it is released to `prod`.
  * It is recommended to not allow the person who created the PR to approve thier own PRs
  * You should review the other available branch policies to see whether you would like to implement any other branch policies
  * You should review security policies on the release environments, to see whether you would like to implement any environment-based controls (eg. 'environment owner approvals' or 'release windows outside core business hours')

# Overview

One of the biggest thing we have identified with DataOps is that the People are just as important as the process. eg. Where is the delineation of what the Data Engineer does vs the DevOps Engineer does.

DevOps = People + Process + Technology

Data DevOps issues then build from people not having a full understanding of how to devops data. This is a problem because devops for data is relatively new when compared to DevOps for Infrastructure as Code (IAC) or applications.

This repo aims to provide a relatively simple working example of a DevOps'd IAC environment, with DataOps setup for the pipelines which ingest the data to the data lake.

For more information on DataOps, review these two repositories:
* https://github.com/Azure-Samples/modern-data-warehouse-dataops
* https://github.com/microsoft/WhatTheHack/tree/master/003-DrivingMissData

## DataOps Background
A DataOps approach improves a project’s ability to stay on target & on time. DataOps is an emerging discipline that brings together DevOps teams with data engineer and data scientis to provide the tools, processes and organization structures to support the data-focused enterprise. DataOps ensures that processes and systems that control the data journey are scalable and repeatable. The activities that fall under the DataOps umbrella include integrating with data sources, performing transformations, converting data formats, and writing or delivering data to its required destination. DataOps also encompasses the monitoring and governance of data flows while ensuring security. 

### Advantages of a DataOps Approach 
* Able to pivot & respond to real-world events as they happen 
* Improved efficiency and better use of people’s time 
* Faster time-to-value 
* A good fit to working with a global data fabric 

### DataOps: A Good Way to Adapt to Emerging Data Practices 
* Faster time-to-value & better ability to pivot
* Better collaboration/communication across skill groups 
* Focused around data-related goals 
* More efficient use of team members’ time 
* A good fit to working with a data fabric 

## What is DataOps?

What is DataOps, exactly, and why are companies planning to invest in it? In a nutshell, DataOps controls the flow of data from source to value, speeding up the process of deriving value from data. Fundamentally, DataOps ensures that processes and systems that control the data journey are scalable and repeatable.

The activities that fall under the DataOps umbrella include integrating with data sources, performing transformations, converting data formats, and writing or delivering data to its required destination. DataOps also encompasses the monitoring and governance of data flows while ensuring security

### Issues related to lack of DevOps:
* Poor teamwork within the data team
* Lack of collaboration between groups within the data organization
* Waiting for IT to disposition or configure system resources
* Waiting for access to data
* Moving slowly and cautiously to avoid poor quality
* Requiring approvals, such as from an Impact Review Board
* Inflexible data architectures
* Process bottlenecks
* Technical debt from previous deployments
* Poor quality creating unplanned work
