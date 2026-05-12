Prerequisite: [EKS Terragrunt](https://www.notion.so/EKS-Terragrunt-30d3205f20be8048a6eddd6450e4c8e4?pvs=21)

# Overview

Before we can expose ArgoCD over HTTPS, we need a domain name backed by a valid TLS certificate. AWS Certificate Manager (ACM) validates domain ownership by writing a CNAME record into a public Route 53 hosted zone, so that zone must exist and be authoritative before we deploy the EKS stack.

We'll build the `setup_dns` bootstrap to create that public hosted zone for the subdomain and output the name servers to delegate at the registrar. Run it once per environment before deploying the EKS stack.

# Setup DNS Components

A Route 53 hosted zone is a container for DNS records for a specific domain or subdomain. When you create a hosted zone for `argocd.example.yourdomain.com`, Route 53 becomes the authoritative DNS server for that subdomain and assigns it 4 name servers. Any DNS query for that subdomain (and its records) is answered by those name servers.

We need one because ACM validates domain ownership by checking a CNAME record in the zone. Without an authoritative public hosted zone, ACM has no way to confirm we control the domain and will not issue the certificate.

We'll use a two-zone pattern to serve ArgoCD over HTTPS while keeping it internal.

## Public Hosted Zone

The public zone is authoritative on the internet. ACM performs DNS validation by checking a CNAME record in it (this requires the zone to be publicly resolvable). The `setup_dns` bootstrap creates this zone once, and its name servers must be delegated at the registrar.

## Private Hosted Zone

The private zone is associated with the VPC (`private_zone = true`). ExternalDNS writes A records here pointing to the internal ALB. DNS queries from inside the VPC resolve to the ALB, and queries from outside the VPC get no answer.

Using both zones lets us issue a valid TLS certificate (which requires public DNS) while keeping the ArgoCD endpoint reachable only from within the network. The private zone is created as part of the EKS stack in the [ArgoCD article](argocd.md).

# Setup DNS Pipeline Implementation

Start by creating a branch:
```bash
git checkout -b setup-dns
```

## Hosted Zone Module

Here's the native Terraform for the public hosted zone:

```hcl
resource "aws_route53_zone" "this" {
  name    = "argocd.example.yourdomain.com"
  comment = "Managed by Terraform"
}

output "name_servers" {
  description = "The list of name servers for the hosted zone (delegate these to your domain registrar)"
  value       = aws_route53_zone.this.name_servers
}
```

## Hosted Zone Unit

Create the hosted zone unit:

```hcl
# units/eks/route53/hosted_zone_public/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_hcl = find_in_parent_folders("environment.hcl")
  environment     = read_terragrunt_config(local.environment_hcl).locals.environment

  dns_config_hcl = find_in_parent_folders("dns_config.hcl")
  base_domain    = read_terragrunt_config(local.dns_config_hcl).locals.base_domain
  subdomain      = read_terragrunt_config(local.dns_config_hcl).locals.subdomain
  domain_name    = "${local.subdomain}.${local.environment}.${local.base_domain}"
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/route53_hosted_zone?ref=${values.version}"
}

inputs = {
  create  = values.create
  name    = local.domain_name
  comment = values.comment
  tags = {
    environment = local.environment
  }
}
```

The `domain_name` is assembled from `dns_config.hcl` and `environment.hcl`, so the same unit produces `argocd.dev.yourdomain.com`, `argocd.staging.yourdomain.com`, etc. without duplication.

The `create` input controls whether the unit creates the zone or reads an existing one via a data source. The bootstrap always passes `create = true`. The EKS stack references the same unit with `create = false` to look up the zone without managing it.

## Hosted Zone Stack

Create the reusable stack:

```hcl
# stacks/setup_dns/terragrunt.stack.hcl
unit "route53_hosted_zone" {
  source = "git::git@github.com:${local.github_username}/${local.github_repo_name}.git//units/eks/route53/hosted_zone_public?ref=${values.version}"
  path   = "eks/route53/hosted_zone_public"

  values = {
    version = values.version
    comment = "Managed by Terraform"
    create  = true
  }
}
```

## Bootstrap Pipeline

Wire it into the environment-specific pipeline:

```hcl
# pipelines/bootstrap/setup_dns/example/stack/terragrunt.stack.hcl
locals {
  version = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals.version

  github_locals    = read_terragrunt_config(find_in_parent_folders("github.hcl")).locals
  github_username  = local.github_locals.github_username
  github_repo_name = local.github_locals.github_repo_name
}

stack "setup_dns" {
  source = "github.com/${local.github_username}/${local.github_repo_name}//stacks/setup_dns?ref=${local.version}"
  path   = "setup_dns"
  values = {
    version = local.version
  }
}
```

# Configure Your Domain

In `pipelines/dns_config.hcl`, set your base domain and subdomain:

```hcl
locals {
  base_domain = "yourdomain.com"
  subdomain   = "argocd"
}
```

You'll need a registered domain with access to its DNS settings. If you don't have one, register one through a domain registrar such as GoDaddy or Namecheap.

In `pipelines/region.hcl`, set your target AWS region:

```hcl
locals {
  region = "eu-west-3"
  azs    = ["eu-west-3a", "eu-west-3b"]
}
```

# Deploy

From the root of the repository, generate and apply the stack for the `example` environment:

```bash
source .env
cd pipelines/bootstrap/setup_dns/example/stack
terragrunt stack generate
terragrunt run --all apply --backend-bootstrap --non-interactive
```

Retrieve the 4 name servers from the output:

```bash
terragrunt stack output --json setup_dns.route53_hosted_zone.name_servers
```

# Delegate the Subdomain

In your domain registrar, add 4 NS records for the subdomain using the name servers from the output above:

| Type | Host | Value |
|------|------|-------|
| NS | `argocd.example` | `ns-123.awsdns-12.com` |
| NS | `argocd.example` | `ns-456.awsdns-34.net` |
| NS | `argocd.example` | `ns-789.awsdns-56.org` |
| NS | `argocd.example` | `ns-012.awsdns-78.co.uk` |

Replace `argocd.example` with your actual `<subdomain>.<environment>` and each value with the name servers from the output.

Read [Routing traffic for a subdomain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html) for the full delegation guide.

# Verify Propagation

```bash
dig NS argocd.example.yourdomain.com
```

Delegation is working when 4 AWS name servers appear in the `ANSWER SECTION`. Propagation usually completes within minutes.

Commit and push the changes:

```bash
git add .
git commit -m "add setup_dns bootstrap"
git push origin setup-dns
```

Open a pull request and merge once the pipeline passes.

The hosted zone must stay alive for the EKS stack to function. ACM certificate validation and ExternalDNS both depend on it. Only destroy it if you are tearing down the full environment.

# Destroy (Optional)

```bash
cd pipelines/bootstrap/setup_dns/example/stack
terragrunt run --all destroy --non-interactive
```
