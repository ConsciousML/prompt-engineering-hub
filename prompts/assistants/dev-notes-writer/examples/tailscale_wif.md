# Overview

The Tailscale components from the previous note (ACL, Kubernetes Operator, Connector, Split DNS) are managed by Terraform and need to authenticate to the Tailscale API.

In CI, storing a static Tailscale OAuth secret in GitHub is risky: if it leaks, it gives permanent API access until you manually revoke it.

Workload Identity Federation (WIF) solves this.

GitHub Actions can request a signed OIDC JWT from GitHub's identity provider (`https://token.actions.githubusercontent.com`).

Tailscale accepts that JWT and issues a short-lived API token scoped to specific permissions and tags. No static secret stored anywhere.

# Prerequisites

[Tailscale Kubernetes VPN](https://www.notion.so/Tailscale-Kubernetes-VPN-34b3205f20be8062b7aff9d9217c42a1?pvs=21) 

# Implementation

## Access Control (ACL)

CI needs `tag:ci` to create devices and OAuth clients on the tailnet. We extend the existing ACL in the bootstrap stack:

```hcl
# pipelines/bootstrap/tailscale/terragrunt.stack.hcl
locals {
  ci_tag = "tag:ci"
}

unit "acl" {
  # ...
  values = {
    acl = jsonencode({
      tagOwners = {
        (local.ci_tag)     = []
        "tag:k8s-operator" = [(local.ci_tag)]
        "tag:k8s"          = ["tag:k8s-operator"]
      }
      autoApprovers = {
        routes = {
          "${local.vpc_cidr}" = ["tag:k8s-operator", "tag:k8s"]
        }
      }
    })
  }
}
```

`tag:ci` owns itself so it can join devices. `tag:k8s-operator` is owned by `tag:ci` because Terratest needs to provision the Tailscale Kubernetes Operator (which uses this tag), and Tailscale requires the OAuth client to own the tag it assigns.

## Federated Identity

The `tailscale_federated_identity` resource tells Tailscale to trust JWT tokens from GitHub Actions and exchange them for API tokens.

We start by creating the module:

```hcl
# modules/tailscale_wif/providers.tf
provider "tailscale" {}

# modules/tailscale_wif/versions.tf
terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28.0"
    }
  }
  required_version = ">= 1.9.1"
}

# modules/tailscale_wif/variables.tf
variable "issuer" {
  description = "OIDC issuer URL for the federated identity"
  type        = string
}

variable "subject" {
  description = "OIDC subject claim pattern (e.g. repo:<org>/<repo>:*)"
  type        = string
}

variable "scopes" {
  description = "OAuth scopes for auth keys issued via this federated identity"
  type        = set(string)
  default     = ["devices:core", "auth_keys", "dns"]
}

variable "tags" {
  description = "Tags assigned to devices authenticated via this federated identity"
  type        = set(string)
}

# modules/tailscale_wif/main.tf
resource "tailscale_federated_identity" "this" {
  issuer  = var.issuer
  subject = var.subject
  scopes  = var.scopes
  tags    = var.tags
}

# modules/tailscale_wif/outputs.tf
output "client_id" {
  description = "The WIF OAuth client ID"
  value       = tailscale_federated_identity.this.id
}

output "audience" {
  description = "The WIF audience value (api.tailscale.com/<client_id>)"
  value       = "api.tailscale.com/${tailscale_federated_identity.this.id}"
}
```

The `audience` output embeds the `client_id` into the format Tailscale expects when validating the JWT. 

GitHub Actions needs to request a token with this exact audience so Tailscale can match it to the right federated identity.

You noticed how we left `provider "tailscale" {}` without arguments?

This is on purpose cause we need to use different argument in local and CI:

- When we want to use the provider locally, we’ll provide the `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET` environment variables.
- Whereas in the CI, we’ll use `TAILSCALE_IDENTITY_TOKEN` to authenticate through OIDC.

Next, we create the unit:

```hcl
# units/tailscale/workflow_identity_federation/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/tailscale_wif?ref=${values.version}"
}

dependency "acl" {
  config_path  = "../acl"
  skip_outputs = true
}

inputs = {
  issuer  = values.issuer
  subject = values.subject
  scopes  = values.scopes
  tags    = values.tags
}
```

The `acl` dependency has no consumed outputs. It enforces that `tag:ci` exists in the policy file before the federated identity is created. Tailscale will reject a federated identity that references a tag not yet declared in the ACL.

Finally, we add the unit to the bootstrap stack:

```hcl
# pipelines/bootstrap/tailscale/terragrunt.stack.hcl
locals {
  version  = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals.version

  github_locals    = read_terragrunt_config(find_in_parent_folders("github.hcl")).locals
  github_username  = local.github_locals.github_username
  github_repo_name = local.github_locals.github_repo_name

  # Tailscale tag assigned to CI runner devices joining via WIF
  ci_tag = "tag:ci"
  
  # Rest of the locals ...
}

# ACL Unit ...

unit "tailscale_wif" {
  source = "git::git@github.com:${local.github_username}/${local.github_repo_name}.git//units/tailscale/workflow_identity_federation?ref=${local.version}"
  path   = "tailscale/workflow_identity_federation"

  values = {
    version = local.version
    issuer  = "https://token.actions.githubusercontent.com"
    subject = "repo:${local.github_username}/${local.github_repo_name}:*"
    scopes  = ["all"]
    tags    = [local.ci_tag]
  }
}
```

`subject` uses a wildcard so any workflow in the repository can exchange tokens.

Here, we use `scopes  = ["all"]` for convenience. It is acceptable because only GitHub Actions can authenticate with these scopes (permissions) on this specific repository.

You can narrow the scopes down if necessary to improve security.

## GitHub Secrets

The WIF client ID and audience have to be available as GitHub secrets so the CI workflow can use them. We automate this instead of copy-pasting values after each apply.

We start by creating the module:

```hcl
# modules/tailscale_github_secrets/providers.tf
provider "github" {
  token = var.github_token
}

# modules/tailscale_github_secrets/versions.tf
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6.0"
    }
  }
  required_version = ">= 1.9.1"
}

# modules/tailscale_github_secrets/variables.tf
variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_repo_name" {
  type = string
}

variable "oauth_client_id" {
  description = "Tailscale WIF client ID (TS_OAUTH_CLIENT_ID)"
  type        = string
  sensitive   = true
}

variable "audience" {
  description = "Tailscale WIF audience value (TS_AUDIENCE)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Comma-separated Tailscale tags assigned to CI runner devices (TS_TAGS)"
  type        = string
}

# modules/tailscale_github_secrets/main.tf
resource "github_actions_secret" "ts_oauth_client_id" {
  repository      = var.github_repo_name
  secret_name     = "TS_OAUTH_CLIENT_ID"
  plaintext_value = var.oauth_client_id
}

resource "github_actions_secret" "ts_audience" {
  repository      = var.github_repo_name
  secret_name     = "TS_AUDIENCE"
  plaintext_value = var.audience
}

resource "github_actions_secret" "ts_tags" {
  repository      = var.github_repo_name
  secret_name     = "TS_TAGS"
  plaintext_value = var.tags
}
```

`oauth_client_id` and `audience` are marked `sensitive` to keep them out of plan output even though they end up encrypted in GitHub.

This module creates the `TS_OAUTH_CLIENT_ID` and `TS_AUDIENCE` secret that will be used later in GitHub Actions for authentication.

Next, we create the unit:

```hcl
# units/tailscale/github_secrets/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/tailscale_github_secrets?ref=${values.version}"
}

dependency "tailscale_wif" {
  config_path = "../workflow_identity_federation"
  mock_outputs = {
    client_id = "mock-client-id"
    audience  = "api.tailscale.com/mock-client-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  github_token     = values.github_token
  github_repo_name = values.github_repo_name
  oauth_client_id  = dependency.tailscale_wif.outputs.client_id
  audience         = dependency.tailscale_wif.outputs.audience
  tags             = values.tags
}
```

Finally, we add the unit to the bootstrap stack:

```hcl
# pipelines/bootstrap/tailscale/terragrunt.stack.hcl
locals {
  version  = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals.version

  github_locals    = read_terragrunt_config(find_in_parent_folders("github.hcl")).locals
  github_username  = local.github_locals.github_username
  github_repo_name = local.github_locals.github_repo_name

  # Tailscale tag assigned to CI runner devices joining via WIF
  ci_tag = "tag:ci"
  
  # Other locals ...
}

# ACL Unit ...

# WIF Unit ...

unit "tailscale_github_secrets" {
  source = "git::git@github.com:${local.github_username}/${local.github_repo_name}.git//units/tailscale/github_secrets?ref=${local.version}"
  path   = "tailscale/github_secrets"

  values = {
    version          = local.version
    github_token     = get_env("GITHUB_TOKEN")
    github_repo_name = local.github_repo_name
    tags             = local.ci_tag
  }
}
```

Then we run the stack:

```bash
source .env
cd pipelines/bootstrap/tailscale
terragrunt stack run apply
```

After apply, three secrets appear in the repository settings: `TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE`, and `TS_TAGS`.

## GitHub Actions

### Authentication

Every CI job needs to authenticate to the Tailscale provider. We request a GitHub OIDC JWT scoped to the Tailscale audience and export it alongside the client ID:

```yaml
- name: Get Tailscale identity token
  uses: actions/github-script@v7
  with:
    script: |
      const token = await core.getIDToken('${{ secrets.TS_AUDIENCE }}')
      core.setSecret(token)
      core.exportVariable('TAILSCALE_IDENTITY_TOKEN', token)
      core.exportVariable('TAILSCALE_OAUTH_CLIENT_ID', '${{ secrets.TS_OAUTH_CLIENT_ID }}')
```

The Tailscale Terraform provider reads `TAILSCALE_IDENTITY_TOKEN` and `TAILSCALE_OAUTH_CLIENT_ID` automatically. Any `plan` or `apply` step after this authenticates without a stored secret.

### Terratest

The same env vars are available when Terratest runs, so the Tailscale provider inside the Go tests picks them up automatically:

```yaml
- name: Run Terratest
  run: go test -v ./tests/... -timeout ${{ env.TERRATEST_TIMEOUT }}
```

No credentials to inject, no secrets to rotate. WIF handles auth end to end.

## Testing

After running the bootstrap stack and triggering a CI run with the `run-terratest` label:

- In the Actions run logs, the `Get Tailscale identity token` step shows a masked token being set.
- In [Tailscale admin Auth Keys](https://login.tailscale.com/admin/machines), the CI runner joins and leaves with `tag:ci` during the `setup` step.
