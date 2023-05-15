# Migration Plan v1.5

- [Migration Plan v1.5](#migration-plan-v15)
  - [Prerequisites](#prerequisites)
  - [Step 1: Install Git for Windows](#step-1-install-git-for-windows)
  - [Step 2: Install PowerShell 7.3.0](#step-2-install-powershell-730)
  - [Step 3: Install NodeJS](#step-3-install-nodejs)
  - [Step 4: Install Docker Desktop for Windows](#step-4-install-docker-desktop-for-windows)
  - [Step 5: Install GitHub CLI](#step-5-install-github-cli)
    - [Winget](#winget)
    - [Signed MSI](#signed-msi)
  - [Step 6: Install the GitHub Enterprise Importer (GEI) extension of the GitHub CLI](#step-6-install-the-github-enterprise-importer-gei-extension-of-the-github-cli)
  - [Step 7: Clone this Repository](#step-7-clone-this-repository)
  - [Step 8: Install NuGet CLI](#step-8-install-nuget-cli)
  - [Step 9: Set environment variables](#step-9-set-environment-variables)
  - [Step 10: Migrate your organization](#step-10-migrate-your-organization)
  - [Step 11: Migrate GitHub Packages](#step-11-migrate-github-packages)
  - [Step 12: Reclaim mannequins](#step-12-reclaim-mannequins)
  - [Appendix](#appendix)
    - [Create Personal Access Tokens](#create-personal-access-tokens)

## Prerequisites

1. To migrate an organization, you must be an organization owner for the **source organization**. Additionally, you must be an **enterprise owner on the destination enterprise** account

## Step 1: Install Git for Windows

1. Download and install [Git for Windows](https://github.com/git-for-windows/git/releases/download/v2.38.1.windows.1/Git-2.38.1-64-bit.exe)
2. Once installed, Git is available from the command prompt or PowerShell

> It's recommended that you select the defaults during installation unless there's good reason to change them

## Step 2: Install PowerShell 7.3.0

To install PowerShell on Windows, use the following links to download the install package from GitHub.

1. [PowerShell-7.3.0-win-x64.msi](https://github.com/PowerShell/PowerShell/releases/download/v7.3.0/PowerShell-7.3.0-win-x64.msi)

## Step 3: Install NodeJS

1. Follow the install instructions on the [windows-nvm repository](https://github.com/coreybutler/nvm-windows#installation--upgrades)
2. Download the `nvm-setup.zip` file for the most recent release.
3. Once downloaded, open the zip file, then open the nvm-setup.exe file.
4. The Setup-NVM-for-Windows installation wizard will walk you through the setup steps, including choosing the directory where both nvm-windows and Node.js will be installed.
5. Once the installation is complete. Open PowerShell (recommend opening with elevated Admin permissions) and try using windows-nvm to list which versions of Node are currently installed (should be none at this point):

    ```posh
    nvm ls
    ```

6. Install the latest stable LTS release of Node.js (recommended) by first looking up what the current LTS version number is with:

    ```posh
    nvm list available
    ```

    then installing the LTS version number with (replacing `<version>` with the number, ie: nvm install 18.12.1):

    ```posh
    nvm install <version>
    ```

    After installing the Node.js, select the version that you would like to use by entering (replacing `<version>` with the number, ie: nvm use 18.12.1):

    ```posh
    nvm use <version>
    ```

    Finally, install the following npm packages:

    ```posh
    npm install -g rimraf
    npm install -g typescript
    npm install -g copyfiles
    ```

## Step 4: Install Docker Desktop for Windows

1. Download `Docker Desktop for Windows` from this link <https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe>. It typically downloads to your Downloads folder, or you can run it from the recent downloads bar at the bottom of your web browser.
2. Double-click Docker Desktop Installer.exe to run the installer.
3. When prompted, ensure the Use WSL 2 instead of Hyper-V option on the Configuration page is selected or not depending on your choice of backend
If your system only supports one of the two options, you will not be able to select which backend to use.
4. Follow the instructions on the installation wizard to authorize the installer and proceed with the install.
5. When the installation is successful, click Close to complete the installation process.
6. If your admin account is different to your user account, you must add the user to the docker-users group. Run Computer Management as an administrator and navigate to Local Users and Groups > Groups > docker-users. Right-click to add the user to the group. Log out and log back in for the changes to take effect.

## Step 5: Install GitHub CLI

### Winget

| Install                          | Upgrade                          |
|:--------------------------------:|:--------------------------------:|
| `winget install --id GitHub.cli` | `winget upgrade --id GitHub.cli` |

### Signed MSI

MSI installers are available for download on the [releases page](https://github.com/cli/cli/releases/latest).

## Step 6: Install the GitHub Enterprise Importer (GEI) extension of the GitHub CLI

| Install                              | Upgrade                              |
|:------------------------------------:|:------------------------------------:|
| `gh extension install github/gh-gei` | `gh extension upgrade github/gh-gei` |

## Step 7: Clone this Repository

1. Open PowerShell (recommend opening with elevated Admin permissions)
2. Change the current working directory to the location where you want the cloned directory.
3. Type `git clone https://github.com/martins-vds/gh-migration-scripts`

    ```posh
    git clone https://github.com/martins-vds/gh-migration-scripts
    ```

4. Press Enter to create your local clone.

## Step 8: Install NuGet CLI

1. In PowerShell (recommend opening with elevated Admin permissions), change the current working directory to the cloned directory

    ```posh
    cd goa-gh-migration
    ```

2. In PowerShell, run the script `setup-nuget.ps1`:

    ```posh
    .\scripts\setup-nuget.ps1
    ```

## Step 9: Set environment variables

Before you can use the GEI extension to migrate to GitHub Enterprise Cloud, you must create personal access tokens (classic) that can access the source organization and destination enterprise, then set the personal access tokens (classic) as environment variables.

> See [**Appendix: Create Personal Access Tokens**](#create-personal-access-tokens) for instructions

1. Create and record a personal access token that meets all the requirements to authenticate for the source organization for organization migrations.
2. Create and record a personal access token (classic) that meets all the requirements to authenticate for the destination enterprise for organization migrations.
3. Set environment variables for the personal access tokens (classic), replacing **TOKEN** in the commands below with the personal access tokens (classic) you recorded above. Use GH_PAT for the destination enterprise and GH_SOURCE_PAT for the source organization.
   - Using PowerShell, use the `$env` command.

    ```posh
    [Environment]::SetEnvironmentVariable("GH_SOURCE_PAT", "TOKEN", [EnvironmentVariableTarget]::User);
    [Environment]::SetEnvironmentVariable("GH_PAT", "TOKEN", [EnvironmentVariableTarget]::User);
    ```

## Step 10: Migrate your organization

To migrate an organization, use the `gh gei migrate-org` command.

```posh
gh gei migrate-org --github-source-org <SOURCE> --github-target-org <DESTINATION> --github-target-enterprise <ENTERPRISE> --wait
```

Replace the placeholders in the command above with the following values.

|Placeholder|Value|
|-----------|-----|
|SOURCE|Name of the source organization|
|DESTINATION|The name you want the new organization to have. Must be unique on GitHub.com|
|ENTERPRISE|The slug for your destination enterprise, which you can identify by looking at the URL for your enterprise account, <https://github.com/enterprises/SLUG>|

## Step 11: Migrate GitHub Packages

> Important: At the time of this writing, the GitHub Enterprise Importer does NOT migrate GitHub Packages. In the future, running this step might not be necessary.

1. In PowerShell (recommend opening with elevated Admin permissions), change the current working directory to the cloned directory

    ```posh
    cd goa-gh-migration
    ```

2. To migrate Nuget packages, run the script `migrate-nuget-packages.ps1` under the `scripts` folder.

    ```posh
    .\scripts\migrate-nuget-packages.ps1 -SourceOrg <SOURCE> -TargetOrg <TARGET> -SourceUsername <SOURCE_USERNAME> -TargetUsername <TARGET_USERNAME> -PackagesPath <PATH> -MaxVersions <VERSIONS>
    ```

    Replace the placeholders in the command above with the following values.

    |Placeholder|Value|
    |-----------|-----|
    |SOURCE|Name of the source organization|
    |TARGET|Name of the target organization|
    |SOURCE_USERNAME|Your GitHub username in the source organization|
    |TARGET_USERNAME|Your GitHub username in the target organization|
    |PATH|Temporary folder where nuget packages will be downloaded to|
    |VERSIONS|Number of package versions to be migrated|

3. To migrate NPM packages, run the script `migrate-npm-packages.ps1` under the `scripts` folder.

    ```posh
    .\scripts\migrate-npm-packages.ps1 -SourceOrg <SOURCE> -TargetOrg <TARGET> -PackagesPath <PATH> -MaxVersions <VERSIONS>
    ```

    Replace the placeholders in the command above with the following values.

    |Placeholder|Value|
    |-----------|-----|
    |SOURCE|Name of the source organization|
    |TARGET|Name of the target organization|
    |PATH|Temporary folder where npm packages will be downloaded to|
    |VERSIONS|Number of package versions to be migrated|

4. To migrate container images, run the script `migrate-container-images` under the `scripts` folder.

    ```posh
    .\scripts\migrate-container-images.ps1 -SourceOrg <SOURCE> -TargetOrg <TARGET> -SourceUsername <SOURCE_USERNAME> -TargetUsername <TARGET_USERNAME> -MaxVersions <VERSIONS>
    ```

    Replace the placeholders in the command above with the following values.

    |Placeholder|Value|
    |-----------|-----|
    |SOURCE|Name of the source organization|
    |TARGET|Name of the target organization|
    |SOURCE_USERNAME|Your GitHub username in the source organization|
    |TARGET_USERNAME|Your GitHub username in the target organization|
    |VERSIONS|Number of package versions to be migrated|

## Step 12: Reclaim mannequins

1. Optionally, to reclaim mannequins in bulk, create a CSV file that maps mannequins to organization members.

   - To generate a CSV file with a list of mannequins for an organization, use the `gh gei generate-mannequin-csv` command, replacing DESTINATION with the destination organization and FILENAME with a file name for the resulting CSV file.

   Optionally, to include mannequins that have already been reclaimed, add the `--include-reclaimed` flag

    ```posh
    gh gei generate-mannequin-csv --github-target-org DESTINATION --output FILENAME.csv
    ```

    - Edit the CSV file, adding the username of the organization member that corresponds to each mannequin.

    - Save the file.

2. To reclaim mannequins, use the gh gei reclaim-mannequin command.

    - To reclaim mannequins in bulk with the mapping file you created earlier, replace DESTINATION with the destination organization and FILENAME with the file name of the mapping file.

    ```posh
    gh gei reclaim-mannequin --github-target-org DESTINATION --csv FILENAME.csv
    ```

    - To reclaim an individual mannequin, replace DESTINATION with the destination organization, MANNEQUIN with the login of mannequin, and USERNAME with the username of the organization member that corresponds to the mannequin.

    If there are multiple mannequins with the same login, you can replace --mannequin-user MANNEQUIN with --mannequin-ID ID, replacing ID with the ID of the mannequin.

    ```posh
    gh gei reclaim-mannequin --github-target-org DESTINATION --mannequin-user MANNEQUIN --target-user USERNAME
    ```

3. The organization member will receive an invitation via email, and the mannequin will not be reclaimed until the member accepts the invitation.

---

## Appendix

### Create Personal Access Tokens

1. In the upper-right corner of any page, click your profile photo, then click **Settings**.
2. In the left sidebar, click **<> Developer settings**.
3. In the left sidebar, under **Personal access tokens**, click **Tokens (classic)**.
4. Select **Generate new token**, then click Generate new token (classic).
5. Give your token a descriptive name.
6. To give your token an expiration, select the **Expiration** drop-down menu, then click a default or use the calendar picker.
7. Select the scopes below
   - `repo`
   - `workflow`
   - `write:packages`
   - `delete:packages`
   - `admin:org`
   - `read:org`
   - `read:enterprise`
8. Click **Generate token**.
9. Copy the token and save it for later
