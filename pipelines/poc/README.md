# Getting Started

## Introduction

This is a testing ground repo for engineers to prove out infrastructure as code.

* Deploys resources to a location and subscription as defined in [vars-global.yml](./azure-pipelines/vars/vars-global.yml)
* Multi-stage [YAML pipeline](./azure-pipelines/pipeline-poc.yml)
* Resources deployed using [Azure Bicep][bicep] via template [main.bicep](./azure-pipelines/resources/main.bicep)
* Code stored within a feature branch linked to an Azure Boards work item

This allows us to easily identify resources in our subscription for management and housekeeping.

Key things to note:

* This is not designed for deploying long-lived resources
* All resources will be deployed into a resource group dedicated your work item number, e.g., `rg-devops-1234-poc`.
* All changes are to be made inside of a feature branch dedicated to your work item, e.g., `feature/sql-endpoints-1234`.
* Remember to tear down resource groups after they're finished with:

    ```powershell
    az account set --subscription "My Subscription"
    az group delete --name rg-devops-1234-poc --no-wait --yes
    ```

## Prerequisites

* Azure CLI

    ```powershell
    $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest `
        -Uri https://aka.ms/installazurecliwindows `
        -OutFile .\AzureCLI.msi; Start-Process msiexec.exe `
        -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi `
        -Wait

    # Optional: PowerShell Module
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
    ```

* Azure Bicep

    ```powershell
    # Azure CLI
    az bicep install

    # Powershell
    choco upgrade bicep -y
    ```

* AAD account with access to both the Azure DevOps organisation/project and Azure subscription.

## Variables

### Variable Group

The `location` and `subscription` pipeline variables are stored in the global variable group [vg-global] to ensure consistency.

### Templates

The application and environment variables are stored in variable template [vars-global.yml](/azure-pipelines/vars/vars-global.yml).

Additional variables can be added as required inside of your feature branch.

In a multi-environment deployment, each environment would normally also have a `vars-env.yml` variable template.

### Bicep

A JSON has been created called [main.jsonc](./azure-pipelines/resources/params/main.jsonc) which is imported in Bicep module [main.bicep](./azure-pipelines/resources/main.bicep).

Additional objects/items can be added to the JSON as needed for use in your feature branch.

## Deploy

1. Log into Azure DevOps from the CLI:

    ```powershell
    #! --allow-no-subscription is critical as this supports authenticating azure-devops commands
    az login --allow-no-subscriptions
    ```

1. Copy folder [azure-pipelines](./azure-pipelines/) into your cloned target repo

1. Inside your clonder target repo, edit `$title`, `$org`, and `$project` variables, then run the following script:

    ```powershell
    # editable variables
    $title = "SQL Endpoints"                        # work item title, also used for branch and pipeline names
    $org = "https://dev.azure.com/your-org"         # Azure DevOps organisation URL
    $project = "your-project"                       # Azure DevOps project name
    $folderPath = "poc"                             # Azure DevOps pipelines folder to organise the pipeline into
    $yamlPath = "azure-pipelines/pipeline-poc.yml"  # relative path of the YAML pipeline inside the repo

    # retrieve repo name from git path
    $repoPath = git rev-parse --show-toplevel
    $repoName = $repoPath.Split("/")[-1]

    # create work item
    try {
        # retrieve aad user display name
        $assignee = az ad signed-in-user show --query displayName --output tsv

        # create boards work item task
        $taskId = az boards work-item create `
            --title $title `
            --assigned-to $assignee `
            --type Task `
            --org $org `
            --project $project `
            --query id `
            --output tsv
    }
    catch {
        Write-Host "Could not create work item!"
    }

    # create local feature branch from main and push it to origin
    # will delete local feature branch if it already exists
    try {
        # build branch name
        $branchName = "feature/$($title.ToLower().Replace(' ', '-'))-$taskId"

        # checkout main, pull changes, delete local feature branch, checkout feature branch, then push it
        git checkout main
        git pull
        git branch -D $branchName # delete local branch
        git checkout -b $branchName
        git push --set-upstream origin $branchName
    }
    catch {
        "Could not create branch!"
    }

    # create pipeline and variables
    try {
        # build pipeline name
        $pipelineName = $branchName -replace "feature/", ""

        # create pipeline that uses yaml pipeline from the feature branch
        $pipelineId = az pipelines create  `
            --name $pipelineName `
            --org $org `
            --project $project `
            --repository $repoName `
            --repository-type tfsgit `
            --branch $branchName `
            --yaml-path $yamlPath `
            --folder-path $folderPath `
            --skip-run `
            --query id `
            --output tsv

        # add pipeline variables
        az pipelines variable create `
            --name createdBy `
            --pipeline-id $pipelineId `
            --org $org `
            --project $project `
            --value $assignee

        az pipelines variable create `
            --name workItemId `
            --pipeline-id $pipelineId `
            --org $org `
            --project $project `
            --value $taskId
    }
    catch {
        "Could not create pipeline!"
    }
    ```

You can either run the pipeline now, which will just create your resource group, or you can start developing your pipeline/Bicep templates.

1. Link the work item to the feature branch (manual task due to `az boards` not yet supporting adding development links to work items):
    1. Edit the work item in the Azure DevOps portal
    1. Under "Development" click on "Add link"
    1. Select the "poc" repository
    1. Select your feature branch
    1. Press "OK" then "Save"

## First Run

Note that when you run the pipeline for the first time, you will be prompted to permit access to the following resources:

| Type               | Name                                    |
|--------------------|-----------------------------------------|
| Service Connection | My Subscription                         |
| Environment        | POC* (when it reaches the Deploy stage) |

## Track Deployments

You can track your deployments both in Azure DevOps and in the Azure Portal.

## To Do

* Setup
    * Investigate using `az boards` to create a development link on the work item
    * Move everything into a single script and pass as few parameters as possible, potentially just work item subject and short name for a branch.
        * `./createpoc.ps1 -Title "Create SQL Endpoint"`
    * Could it be turned into a pipeline?
* Clean up script after environment is finished with:
    * Mark work item as done
    * Delete branch
    * Delete pipeline
    * Delete resource group
    * `./deletepoc.ps1 -WorkItemId 1234`

<!-- links -->

[bicep]:https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview
