# GitHub Migration Scripts

## Documents

- [Migration Plan v1.5](docs/Migration%20Plan%20v1.5.md)
  - NO LONGER MAINTAINED
- [Migration Plan v2.0 - DRAFT](docs/Migration%20Plan%20v2.0%20-%20DRAFT.md).
  - This is a work in progress. It is not yet complete but is being updated as we learn more about the migration process and it will become the new migration plan.

## Overview

The following scripts are meant to help extract metadata that can be helpful when prioritizing repositories and teams for GitHub to GitHub migration.

|Script|Purpose|Example|
|-|-|-|
|get-repos.ps1|Fetch all repositories with their number of pull requests and issues|.\scripts\get-repos.ps1 -Org my-github-org -OutputFile .\repos.csv|
|get-teams.ps1|Fetch all teams|.\scripts\get-teams.ps1 -Org my-github-org -OutputFile .\teams.csv|
|get-team-repos.ps1|Fetch repositories to which teams have access|.\scripts\get-team-repos.ps1 -Org my-github-org -OutputFile .\team-repos.csv|
|get-team-members.ps1|Fetch team members and their roles|.\scripts\get-team-members.ps1 -Org my-github-org -OutputFile .\team-members.csv|
