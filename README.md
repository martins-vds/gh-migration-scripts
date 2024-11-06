# GitHub Migration Scripts

## Documents

- [Migration Plan v2.0](docs/Migration%20Plan%20v2.0.md).
  - This is a work in progress. It is not yet complete but is being updated as we learn more about the migration process and it will become the new migration plan.

## Scripts Overview

The scripts in this repository are intended to be used to help with the migration of repositories, teams, and secrets from one GitHub organization to another. The scripts are written in PowerShell and use the [GitHub CLI](https://cli.github.com/) to interact with GitHub.

> Note: Parameters in square brackets are **optional**.

|Script Name                         | Purpose                                                   | Example |
|-| -|-|
|create-actions-allow-list.ps1      |  Validates and extract a filtered list of allowed actions from a CSV file for use in GitHub enterprise or organization settings|`.\scripts\create-actions-allow-list.ps1 -ActionsFile .\actions.csv`|
|create-slug-mapping-file.ps1        | Fetches members from a GitHub organization, generates slug mappings based on the retrieved members, and saves the mappings to a CSV file specified.|`.\scripts\create-slug-mapping-file.ps1 -Org my-github-org -OutputFile slug-mapping.csv [-Token <TOKEN>] [-Confirm]` |
|delete-repos.ps1                    | Reads a CSV file containing repository information, prompts for confirmation, and deletes the specified repositories from the GitHub organization specified|`.\scripts\delete-repos.ps1 -Org my-github-org -ReposFile .\repos.csv -Token <TOKEN> [-Confirm]`|
|get-migrations.ps1                  | Retrieves migration information for a GitHub organization, aggregates all the migrations, and saves the information to a CSV file with a timestamped filename.|`.\scripts\get-migrations.ps1 -Org my-github-org [-Token <TOKEN>]`|
|get-org-actions.ps1                 | Retrieves actions from a GitHub organization, determine their properties (such as whether they are allowed, whether they are from GitHub or verified, and their marketplace link), and save the information to a CSV file.|`.\scripts\get-org-actions.ps1 -Org my-github-org -OutputFile .\actions.csv [-Token <TOKEN>] [-Confirm]`|
|get-org-members.ps1                 | Retrieves members from a GitHub organization, retrieve their membership details (such as the member's slug, role, and state), and save this information to a CSV file.|`.\scripts\get-org-members.ps1 -Org my-github-org -OutputFile .\org-members.csv [-Token <TOKEN>] [-Confirm]`|
|get-org-sbom.ps1                    | Retrieves the software bill of materials (SBOM) for each repository from a GitHub organization, and saves the SBOM data as JSON files in a specified output directory.|`.\scripts\get-org-sbom.ps1 -Org my-github-org -OutputDirectory .\sbom [-Token <TOKEN>] [-Confirm]`|
|get-repos.ps1                       | Fetches repositories from a GitHub organization, calculates the number of issues and pull requests for each repository, and saves the repository metrics as a CSV file.|`.\scripts\get-repos.ps1 -Org my-github-org -OutputFile .\repos.csv [-Token <TOKEN>] [-Confirm]`|
|get-team-members.ps1                | Fetches teams from a GitHub organization, retrieves the members of each team, and saves the team and member details as a CSV file.|`.\scripts\get-team-members.ps1 -Org my-github-org -OutputFile .\team-members.csv [-Token <TOKEN>] [-Confirm]`|
|get-team-repos.ps1                  | Fetches teams from a GitHub organization, retrieves the repositories associated with each team, and saves the team-repository mappings as a CSV file.|`.\scripts\get-team-repos.ps1 -Org my-github-org -OutputFile .\team-repos.csv [-Token <TOKEN>] [-Confirm]`|
|get-teams.ps1                       | Retrieves teams from a GitHub organization.|`.\scripts\get-teams.ps1 -Org my-github-org -OutputFile .\teams.csv [-Token <TOKEN>] [-Confirm]` |
|merge-csv-files.ps1                 | Merges CSV files.|`.\scripts\merge-csv-files.ps1 -Path .\csv-folder -OutputFile csv-merged.csv` |
|migrate-org-secrets.ps1            | Migrates organization secrets from one GitHub organization to another.|`.\scripts\migrate-org-secrets.ps1 -SourceOrg my-github-org -TargetOrg my-other-github-org -SecretsFile .\secrets.csv [-SourceToken <SOURCE_TOKEN>] [-TargetToken <TARGET_TOKEN>]`|
|migrate-repo-environments.ps1| Migrates repository environments and its variables from one GitHub organization to another.|`.\scripts\migrate-repo-environments.ps1 -SourceOrg my-github-org -TargetOrg my-other-github-org -ReposFile .\repos.csv [-SourceToken <SOURCE_TOKEN>] [-TargetToken <TARGET_TOKEN>]`|
|migrate-repo-secrets.ps1            | Migrates repository secrets and environment secrets from one GitHub organization to another.|`.\scripts\migrate-repo-secrets.ps1 -SourceOrg my-github-org -TargetOrg my-other-github-org -ReposFile .\repos.csv -SecretsFile .\secrets.csv [-SourceToken <SOURCE_TOKEN>] [-TargetToken <TARGET_TOKEN>]`|
|migrate-repos.ps1                   | Migrates repositories from one GitHub organization to another in parallel.|`.\scripts\migrate-repos.ps1 -SourceOrg my-github-org -TargetOrg my-other-github-org -ReposFile .\repos.csv -Parallel 5 [-AllowPublicRepos] [-ArchiveSourceRepos] [-SourceToken <SOURCE_TOKEN>] [-TargetToken <TARGET_TOKEN>]`|
|migrate-teams.ps1                   | Migrates teams from one GitHub organization to another.|`.\scripts\migrate-teams.ps1 -SourceOrg my-github-org -TargetOrg my-other-github-org -SlugMappingFile .\slug-mapping.csv -ReposFile .\repos.csv [-SkipEmptySlugMappings] [-AddTeamMembers] [-SourceToken <SOURCE_TOKEN>] [-TargetToken <TARGET_TOKEN>]`|
|unarchive-repos.ps1| Unarchive repositories in a specified GitHub organization | `.\scripts\unarchive-repos.ps1 -Org my-github-org -ReposFile .\repos.csv -Token <TOKEN> [-Confirm]`|
