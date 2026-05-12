# Overview

ArgoCD and future internal tools sit behind an internal ALB, unreachable from the public internet.

We’ll integrate Tailscale in the stack as a lightweight VPN layer to access the private VPC network without managing a separate VPN endpoint or certificate authority.

# Components

Here are the Tailscale components we’ll use to access the internal endpoints of our EKS cluster:

- **Tailnet:** private Tailscale network where we can add users, devices, and resources.
- **Access Control (ACL):** tailnet-wide network policies to define access control to our components.
- **Subnet Router** (Connector CRD)**:** adds the VPC where EKS runs as a device to our telnet.
- **Split DNS:** routes DNS queries to your private domain [`yourdomain.com`](http://argocd.dev.yourdomain.com) to the VPC’s DNS
- **Tailscale Kubernetes Operator:** runs inside EKS and manages the subnet router lifecycle via a Kubernetes CRD
- **Workload Identity Federation:** allows CI to authenticate to Tailscale without storing long-lived secrets in GitHub

# Prerequisite

Create an account and login to https://login.tailscale.com/admin/welcome

Download the tailscale client https://tailscale.com/download/macos

Copy the example environment file:

```hcl
cp .env.example .env
```

Go to [Tailscale Trust Credential](https://login.tailscale.com/admin/settings/trust-credentials), then select 

- Click on `+ Credential`
- Select `OAuth` and click on `Continue`
- Select `Scopes > All Read & Write` (or for a fine-grained token, use write access for DNS, Core, Policy File, OAuth and Federated keys)
- Click on `Generate credential`

You should see a window `Credential Added` .

Copy both the client ID and client secret and add them to your `.env` file:

```bash
export TAILSCALE_OAUTH_CLIENT_ID=<your_client_id>
export TAILSCALE_OAUTH_CLIENT_SECRET=<your_client_secret>
```

# Implementation

## Access Control

The ACL resource can only be define once per tailnet, as we’ll create multiple VPCs and clusters, we need to define it once to avoid clashing resources.

We’ll start by creating the Terraform module:

```bash
# modules/tailscale_acl/providers.tf

# The necessary variables will be populated by the .env file
provider "tailscale" {}

# modules/tailscale_acl/versions.tf
terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.19"
    }
  }

  required_version = ">= 1.9.1"
}

# modules/tailscale_acl/variables.tf
variable "acl" {
  description = "The tailnet policy file as a JSON string. Use jsonencode() in the calling unit to construct the policy."
  type        = string
}

variable "overwrite_existing_content" {
  description = "If true, skips the requirement to import the ACL resource before allowing changes"
  type        = bool
  default     = false
}

variable "reset_acl_on_destroy" {
  description = "If true, resets the tailnet policy file to the Tailscale default when this resource is destroyed"
  type        = bool
  default     = false
}

# modules/tailscale_acl/main.tf
resource "tailscale_acl" "this" {
  acl                        = var.acl
  overwrite_existing_content = var.overwrite_existing_content
  reset_acl_on_destroy       = var.reset_acl_on_destroy
}

# modules/tailscale_acl/outputs.tf
output "id" {
  description = "The ID of the Tailscale ACL resource"
  value       = tailscale_acl.this.id
}
```

Next, we create a unit that wraps this module:

```bash
# units/tailscale/acl/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::git@github.com:ConsciousML/terragrunt-template-catalog-eks.git//modules/tailscale_acl?ref=${values.version}"
}

inputs = {
  acl                        = values.acl
  overwrite_existing_content = values.overwrite_existing_content
  reset_acl_on_destroy       = values.reset_acl_on_destroy
}
```

Finally, we create the bootsrap stack that will be run once per repository:

```bash
# pipelines/bootstrap/tailscale/terragrunt.stack.hcl
locals {
  version  = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals.version
  vpc_cidr = read_terragrunt_config(find_in_parent_folders("vpc.hcl")).locals.vpc_cidr
}

unit "acl" {
  source = "git::git@github.com:ConsciousML/terragrunt-template-catalog-eks.git//units/tailscale/acl?ref=${local.version}"
  path   = "tailscale/acl"

  values = {
    version = local.version
    acl = jsonencode({
      tagOwners = {
        "tag:k8s-operator" = []
        "tag:k8s"          = ["tag:k8s-operator"]
      }
      autoApprovers = {
        routes = {
          "${local.vpc_cidr}" = ["tag:k8s-operator", "tag:k8s"]
        }
      }
    })
    overwrite_existing_content = false
    reset_acl_on_destroy       = true
  }
}
```

We use `tagOwners` to allow the Tailscale Kubernetes Operator to use OAuth to manage devices through the Tailscale API.

`autoApprovers` allow to by pass the need to manually approve the resources under the VPC CIDR using `tag:k8s-operator`.

It reads the `vpc.hcl` file for a single source of truth for the VPC CIDR:

```bash
# pipelines/vpc.hcl
locals {
  vpc_cidr = "10.0.0.0/16"
}
```

This file is also read in the `units/vpc/terragrunt.hcl` run by `pipelines/examples/stacks/eks/` to use the same VPC CIDR as the rule.

Finally, we run the stack:

```bash
source .env
cd pipelines/bootstrap/tailscale
terragrunt stack run apply
```

## OAuth Client

The Tailscale Kubernetes Operator needs OAuth client credentials to create Auth Keys for itself and for the devices it creates and manages.

We start by creating the OAuth client module:

```bash
# modules/tailscale_acl/providers.tf
provider "tailscale" {}

# modules/tailscale_oauth_client/versions.tf
# same as `modules/tailscale_acl/versions.tf`

# modules/tailscale_oauth_client/variables.tf
variable "description" {
  description = "A description of the OAuth client"
  type        = string
}

variable "scopes" {
  description = "Scopes to grant to the client. See https://tailscale.com/kb/1623/ for available scopes."
  type        = set(string)
}

variable "tags" {
  description = "Tags that access tokens generated for the OAuth client will be able to assign to devices. Mandatory when scopes include 'devices:core' or 'auth_keys'."
  type        = set(string)
}

# modules/tailscale_oauth_client/main.tf
resource "tailscale_oauth_client" "this" {
  description = var.description
  scopes      = var.scopes
  tags        = var.tags
}

# modules/tailscale_oauth_client/outputs.tf
output "client_id" {
  description = "The OAuth client ID"
  value       = tailscale_oauth_client.this.id
}

output "client_secret" {
  description = "The OAuth client secret"
  value       = tailscale_oauth_client.this.key
  sensitive   = true
}

```

It uses the `tailscale_oauth_client` resource to create an OAuth client similar to what we did in the prerequisites.

Next, we create a unit that calls this module:

```bash
# units/eks/addons/tailscale/oauth_client_tailscale_operator/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment_hcl = find_in_parent_folders("environment.hcl")
  environment     = read_terragrunt_config(local.environment_hcl).locals.environment

  cluster_config_hcl = find_in_parent_folders("cluster_config.hcl")
  cluster_name       = read_terragrunt_config(local.cluster_config_hcl).locals.cluster_name
}

terraform {
  source = "git::git@github.com:ConsciousML/terragrunt-template-catalog-eks.git//modules/tailscale_oauth_client?ref=${values.version}"
}

inputs = {
  description = "${local.environment}-${local.cluster_name}"
  scopes      = ["devices:core", "auth_keys", "services"]
  tags        = ["tag:k8s-operator"]
}
```

It is crucial to use these `scopes` so that the operator can have the required permissions to perform its tasks.

We use the `tag:k8s-operator` tag so that it gets auto approved, and because Tailscale won't let the OAuth client generate auth keys for a tag it doesn't own.

Finally, we call the unit in the EKS stack:

```bash
locals {
  version = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals.version
}

# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "tailscale_oauth_client_tailscale_operator" {
  source = "${get_repo_root()}/units/eks/addons/tailscale/oauth_client_tailscale_operator"
  path   = "eks/addons/tailscale/oauth_client_tailscale_operator"

  values = {
    version = local.version
  }
}

# The rest of the stack
# ...
```

## Tailscale Kubernetes Operator

The Tailscale Kubernetes Operator runs inside EKS and manages Tailscale devices via Kubernetes CRDs.

It uses the OAuth client from the previous step to authenticate to the Tailscale API.

We reuse the existing generic `modules/helm_release/` module and create a unit that injects the OAuth credentials:

```bash
  # units/eks/addons/tailscale/operator/terragrunt.hcl
  include "root" {
    path = find_in_parent_folders("root.hcl")
  }

  include "provider_kubernetes" {
    path = find_in_parent_folders("provider_kubernetes.hcl")
  }

  terraform {
    source =
  "git::git@github.com:ConsciousML/terragrunt-template-catalog-eks.git//modules/helm_release/?ref=${values.version}"
  }

  locals {
    environment_hcl = find_in_parent_folders("environment.hcl")
    environment     = read_terragrunt_config(local.environment_hcl).locals.environment

    cluster_config_hcl = find_in_parent_folders("cluster_config.hcl")
    cluster_name       = read_terragrunt_config(local.cluster_config_hcl).locals.cluster_name

    cluster_name_full = "${local.environment}-${local.cluster_name}"

    cluster_exists = run_cmd("--terragrunt-quiet", "sh", "-c", <<-EOT
      output=$(aws eks describe-cluster --name ${local.cluster_name_full} 2>&1)
      aws_exit_code=$?
      if echo "$output" | grep -q 'ResourceNotFoundException'; then
        echo false
      elif [ $aws_exit_code -ne 0 ]; then
        echo "$output" >&2
        exit 1
      else
        echo true
      fi
    EOT
    )
  }

  dependency "eks_cluster" {
    config_path = "../../../cluster"
    mock_outputs = {
      cluster_name = "mock-cluster"
    }
    mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
  }

  dependency "tailscale_oauth_client_tailscale_operator" {
    config_path = "../oauth_client_tailscale_operator"
    mock_outputs = {
      client_id     = "mock-client-id"
      client_secret = "mock-client-secret"
    }
    mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
  }

  inputs = {
    cluster_name       = dependency.eks_cluster.outputs.cluster_name
    name               = "tailscale-operator"
    repository         = "https://pkgs.tailscale.com/helmcharts"
    chart              = "tailscale-operator"
    namespace          = "tailscale"
    create_namespace   = true
    helm_chart_version = values.helm_chart_version
    helm_values        = {}
    helm_set = [
      {
        name  = "oauth.clientId"
        value = dependency.tailscale_oauth_client_tailscale_operator.outputs.client_id
      }
    ]
    helm_set_sensitive = [
      {
        name  = "oauth.clientSecret"
        value = dependency.tailscale_oauth_client_tailscale_operator.outputs.client_secret
      }
    ]
  }

  exclude {
    if      = !local.cluster_exists
    actions = ["init", "validate", "plan"]
  }
```

The `cluster_exists` guard prevents Terragrunt from initializing before the cluster exists, which would fail the Kubernetes provider authentication.

The OAuth secret is passed via `helm_set_sensitive` to avoid it appearing in plain text in the plan output.

Finally, we call the unit in the EKS stack:

```bash
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
  unit "tailscale_operator" {
    source = "${get_repo_root()}/units/eks/addons/tailscale/operator"
    path   = "eks/addons/tailscale/operator"

    values = {
      version            = local.version
      helm_chart_version = "1.96.5"
    }
  }
```

## Subnet Router (Connector)

The Connector CRD instructs the operator to deploy a subnet router StatefulSet that advertises the VPC's private subnet CIDRs into the tailnet.

This makes the internal ALB reachable from any device on the tailnet.

We start by creating the Terraform module, it uses the `kubernetes_manifest` resource to apply a manifest defined inline that creates the connector:

```bash
# modules/tailscale_connector/versions.tf
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
  }

  required_version = ">= 1.9.1"
}

# modules/tailscale_connector/variables.tf
# tflint-ignore: terraform_unused_declarations
variable "cluster_name" {
  description = "Name of the EKS cluster, used to configure the Kubernetes provider"
  type        = string
}

variable "name" {
  description = "Name of the Connector resource"
  type        = string
}

variable "hostname_prefix" {
  description = "Hostname prefix for the connector device in the tailnet"
  type        = string
}

variable "advertise_routes" {
  description = "List of subnet CIDRs to advertise into the tailnet"
  type        = list(string)
}

variable "replicas" {
  description = "Number of connector replicas"
  type        = number
  default     = 1
}

# modules/tailscale_connector/main.tf
resource "kubernetes_manifest" "connector" {
  manifest = {
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "Connector"
    metadata = {
      name = var.name
    }
    spec = {
      hostnamePrefix = var.hostname_prefix
      replicas       = var.replicas
      subnetRouter = {
        advertiseRoutes = var.advertise_routes
      }
    }
  }
}
```

`cluster_name` is not used in `main.tf` but is required by the Kubernetes provider configuration injected by Terragrunt at runtime.

Next, we create a unit that wraps this module:

```bash
# units/eks/addons/tailscale/connector/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider_kubernetes" {
  path = find_in_parent_folders("provider_kubernetes.hcl")
}

terraform {
  source = "<git::git@github.com>:ConsciousML/terragrunt-template-catalog-eks.git//modules/tailscale_connector/?ref=${values.version}"
}

locals {
  environment_hcl = find_in_parent_folders("environment.hcl")
  environment     = read_terragrunt_config(local.environment_hcl).locals.environment

  cluster_config_hcl = find_in_parent_folders("cluster_config.hcl")
  cluster_name       = read_terragrunt_config(local.cluster_config_hcl).locals.cluster_name

  cluster_name_full = "${local.environment}-${local.cluster_name}"

  cluster_exists = run_cmd("--terragrunt-quiet", "sh", "-c", <<-EOT
    output=$(aws eks describe-cluster --name ${local.cluster_name_full} 2>&1)
    aws_exit_code=$?
    if echo "$output" | grep -q 'ResourceNotFoundException'; then
      echo false
    elif [ $aws_exit_code -ne 0 ]; then
      echo "$output" >&2
      exit 1
    else
      echo true
    fi
  EOT
  )
}

dependency "eks_cluster" {
  config_path = "../../../cluster"
  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

dependency "vpc" {
  config_path = "../../../../vpc"
  mock_outputs = {
    private_subnets_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

dependency "tailscale_operator" {
  config_path                             = "../operator"
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  cluster_name     = dependency.eks_cluster.outputs.cluster_name
  name             = "${local.environment}-${local.cluster_name}-connector"
  hostname_prefix  = "${local.environment}-${local.cluster_name}"
  advertise_routes = dependency.vpc.outputs.private_subnets_cidr_blocks
  replicas         = 1
}

exclude {
  if      = !local.cluster_exists
  actions = ["init", "validate", "plan"]
}
```

`advertise_routes` is pulled from the `vpc` dependency output so it stays in sync with the actual subnets without duplicating values from `vpc.hcl`.

The `tailscale_operator` dependency has no consumed outputs. It enforces ordering so the `Connector` CRD exists in the cluster before Terraform applies the custom resource.

Finally, we call the unit in the EKS stack:

```bash
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "tailscale_connector" {
  source = "${get_repo_root()}/units/eks/addons/tailscale/connector"
  path   = "eks/addons/tailscale/connector"

  values = {
    version = local.version
  }
}
```

## DNS Split

Split DNS routes DNS queries for the private hosted zone domain to the VPC's DNS resolver, so that `argocd.example.axelmendoza.com` resolves to the internal ALB IP from any device on the tailnet.

Each environment creates its own rule pointing to its VPC DNS resolver (`vpc_cidr_base + 2`), so there is no collision across environments.

We start by creating the Terraform module:

```bash
# modules/tailscale_split_dns/providers.tf
provider "tailscale" {}

# modules/tailscale_split_dns/versions.tf
terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28.0"
    }
  }

  required_version = ">= 1.9.1"
}

# modules/tailscale_split_dns/variables.tf
variable "domain" {
  description = "The domain suffix whose DNS queries will be forwarded to the nameservers"
  type        = string
}

variable "nameservers" {
  description = "List of nameserver IPs to forward DNS queries to"
  type        = list(string)
}

# modules/tailscale_split_dns/main.tf
resource "tailscale_dns_split_nameservers" "this" {
  domain      = var.domain
  nameservers = var.nameservers
}
```

Next, we create a unit that wraps this module:

```bash
# units/eks/addons/tailscale/split_dns/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "<git::git@github.com>:ConsciousML/terragrunt-template-catalog-eks.git//modules/tailscale_split_dns?ref=${values.version}"
}

dependency "vpc" {
  config_path = "../../../../vpc"
  mock_outputs = {
    vpc_cidr_block = "10.0.0.0/16"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

dependency "route53_hosted_zone_private" {
  config_path = "../../../route53_hosted_zone_private"
  mock_outputs = {
    domain_name = "argocd.example.axelmendoza.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  domain      = dependency.route53_hosted_zone_private.outputs.domain_name
  nameservers = [cidrhost(dependency.vpc.outputs.vpc_cidr_block, 2)]
}
```

The `domain` is taken directly from the private Route53 hosted zone output — no manual domain construction needed and it stays in sync with the actual deployed zone.

The nameserver is computed from the VPC CIDR block: AWS always places the VPC DNS resolver at `vpc_cidr_base + 2` (e.g. `10.0.0.0/16` → `10.0.0.2`).

Finally, we call the unit in the EKS stack:

```bash
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "tailscale_split_dns" {
  source = "${get_repo_root()}/units/eks/addons/tailscale/split_dns"
  path   = "eks/addons/tailscale/split_dns"

  values = {
    version = local.version
  }
}
```

## Testing

Get the ArgoCD password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Connect to ArgoCD, using `admin` as username and the password you retrieved above:

- With the tailscale client running, https://argocd.example.axelmendoza.com loads in browser
- Connect with the CLI:

```bash
argocd login argocd.example.axelmendoza.com
```
