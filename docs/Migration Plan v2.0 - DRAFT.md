# Migration Plan v2.0 - DRAFT

- [Migration Plan v2.0 - DRAFT](#migration-plan-v20---draft)
  - [Prerequisites](#prerequisites)
  - [Step 1: Install Git for Windows](#step-1-install-git-for-windows)
  - [Step 2: Install PowerShell 7.3.0](#step-2-install-powershell-730)
  - [Step 3: Install GitHub CLI](#step-3-install-github-cli)
    - [Winget](#winget)
    - [Signed MSI](#signed-msi)
  - [Step 4: Install the GitHub Enterprise Importer (GEI) extension of the GitHub CLI](#step-4-install-the-github-enterprise-importer-gei-extension-of-the-github-cli)
  - [Step 5: Clone this Repository](#step-5-clone-this-repository)
  - [Step 6: Set environment variables](#step-6-set-environment-variables)
  - [Step 7: Migrate your organization](#step-7-migrate-your-organization)
  - [Step 12: Reclaim mannequins (Optional)](#step-12-reclaim-mannequins-optional)
  - [Appendix](#appendix)
    - [Create Personal Access Tokens](#create-personal-access-tokens)
    - [Authorizing a personal access token for use with SAML single sign-on](#authorizing-a-personal-access-token-for-use-with-saml-single-sign-on)

## Prerequisites

1. To migrate an organization, you must be an organization owner for the **source organization**. Additionally, you must be an **enterprise owner on the destination enterprise** account

## Step 1: Install Git for Windows

1. Download and install [Git for Windows](https://github.com/git-for-windows/git/releases/download/v2.38.1.windows.1/Git-2.38.1-64-bit.exe)
2. Once installed, Git is available from the command prompt or PowerShell

> It's recommended that you select the defaults during installation unless there's good reason to change them

## Step 2: Install PowerShell 7.3.0

To install PowerShell on Windows, use the following links to download the install package from GitHub.

1. [PowerShell-7.3.0-win-x64.msi](https://github.com/PowerShell/PowerShell/releases/download/v7.3.0/PowerShell-7.3.0-win-x64.msi)

## Step 3: Install GitHub CLI

### Winget

| Install                          | Upgrade                          |
|:--------------------------------:|:--------------------------------:|
| `winget install --id GitHub.cli` | `winget upgrade --id GitHub.cli` |

### Signed MSI

MSI installers are available for download on the [releases page](https://github.com/cli/cli/releases/latest).

## Step 4: Install the GitHub Enterprise Importer (GEI) extension of the GitHub CLI

| Install                              | Upgrade                              |
|:------------------------------------:|:------------------------------------:|
| `gh extension install github/gh-gei` | `gh extension upgrade github/gh-gei` |

## Step 5: Clone this Repository

1. Open PowerShell (recommend opening with elevated Admin permissions)
2. Change the current working directory to the location where you want the cloned directory.
3. Type `git clone https://github.com/martins-vds/gh-migration-scripts`

    ```posh
    git clone https://github.com/martins-vds/gh-migration-scripts
    ```

4. Press Enter to create your local clone.

## Step 6: Set environment variables

Before you can use the GEI extension to migrate to GitHub Enterprise Cloud, you must create personal access tokens (classic) that can access the source organization and destination enterprise, then set the personal access tokens (classic) as environment variables.

> See [**Appendix: Create Personal Access Tokens**](#create-personal-access-tokens) for instructions

1. Create and record a personal access token that meets all the requirements to authenticate for the
source organization for organization migrations.

2. Create and record a personal access token (classic) that meets all the requirements to authenticate for the destination enterprise for organization migrations.

3. Set environment variables for the personal access tokens (classic), replacing **TOKEN** in the commands below with the personal access tokens (classic) you recorded above. Use GH_PAT for the destination enterprise and GH_SOURCE_PAT for the source organization.
   - Using PowerShell, use the `$env` command.

    ```posh
    [Environment]::SetEnvironmentVariable("GH_SOURCE_PAT", "TOKEN", [EnvironmentVariableTarget]::User);
    [Environment]::SetEnvironmentVariable("GH_PAT", "TOKEN", [EnvironmentVariableTarget]::User);
    ```

4. Close and reopen PowerShell (recommend opening with elevated Admin permissions) to ensure the GH_PAT and GH_SOURCE_PAT environment variables are updated and available.

## Step 7: Migrate your organization

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

## Step 12: Reclaim mannequins (Optional)

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
   - `delete_repo`
8. Click **Generate token**.
9. Copy the token and save it for later
10. If your organization requires SAML single sign-on for authentication, you must authorize your personal access token for use with SAML single sign-on. For more information, see [**Authorizing a personal access token for use with SAML single sign-on**](#authorizing-a-personal-access-token-for-use-with-saml-single-sign-on).

### Authorizing a personal access token for use with SAML single sign-on

1. In the upper-right corner of any page, click your profile photo, then click **Settings**.
2. In the left sidebar, click **Developer settings**.
3. In the left sidebar, click **Personal access tokens**.
4. Next to the token you'd like to authorize, click **Configure SSO**. If you don't see Configure SSO, ensure that you have authenticated at least once through your SAML IdP to access resources on GitHub.com
5. In the dropdown menu, to the right of the organization you'd like to authorize the token for, click **Authorize**.
