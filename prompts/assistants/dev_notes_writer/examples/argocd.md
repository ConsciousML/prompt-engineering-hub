# Overview

Here's how we will have ArgoCD available for internal teams:

1. Run the `setup_dns` bootstrap to create a public Route53 hosted zone for the subdomain. It outputs 4 name servers.
2. Manual step: add those 4 name servers to the parent domain as NS records in Namecheap. This delegates authority for the subdomain to Route 53.
3. Use AWS Certificate Manager (ACM) to issue a TLS certificate for the subdomain. ACM validates we own the domain by checking a CNAME record we add to the public hosted zone.
4. Create a private Route53 hosted zone for the same domain name, associated with the VPC. ExternalDNS writes A records here so the domain resolves to the internal ALB only from within the VPC.
5. Install the AWS Load Balancer Controller (LBC) into the cluster. When we create a k8s Ingress for ArgoCD, it provisions an internal Application Load Balancer (ALB) that uses the ACM certificate to serve HTTPS traffic.
6. Install the ExternalDNS controller that will update the private hosted zone when we create an Ingress resource (i.e. it'll add the internal ALB hostname as an alias record to the subdomain).
7. Install ArgoCD with Helm with an Ingress pointing to the internal ALB.

ArgoCD is intended for internal teams only, so we keep it off the public internet. Access requires Tailscale VPN. See the Tailscale article for setup instructions.

# Prerequisites

Before starting, make sure you have the following in place:

- AWS account with billing enabled
- GitHub account
- `AdministratorAccess` AWS IAM permissions
- A registered domain with access to its DNS settings
- The [EKS stack](https://www.notion.so/EKS-Terragrunt-30d3205f20be8048a6eddd6450e4c8e4?pvs=21) deployed
- The `setup_dns` bootstrap applied and the subdomain delegated at your registrar

You'll also need to be familiar with:

- [Kubernetes](https://www.axelmendoza.com/posts/kubernetes-beginner-guide/)
- [Terragrunt](https://www.axelmendoza.com/posts/terraform-vs-terragrunt/)
- [Helm](https://helm.sh/docs/intro/quickstart/)

# DNS Setup

Before deploying the EKS stack, follow the Setup DNS guide to create the public hosted zone, delegate the subdomain at your registrar, and understand the public/private zone pattern used throughout this article.

# ArgoCD Pipeline Implementation

Create a branch:

```bash
git checkout -b argocd
```

## ACM Certificate and Private Hosted Zone

To issue a TLS certificate we need a domain name in a public hosted zone. ACM validates ownership by writing a CNAME record into that zone.

### ACM Certificate Module

We'll start by creating the ACM certificate module:

```hcl
# modules/acm_certificate/versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.9.1"
}

# modules/acm_certificate/variables.tf
variable "domain_name" {
  description = "The domain name for the ACM certificate (e.g. argocd.dev.yourdomain.com)"
  type        = string
}

variable "zone_id" {
  description = "The Route53 hosted zone ID to create the DNS validation record in"
  type        = string
}

# modules/acm_certificate/main.tf
resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"
}

resource "aws_route53_record" "this" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
}

# modules/acm_certificate/outputs.tf
output "certificate_arn" {
  description = "The certificate ARN created by ACM"
  value       = aws_acm_certificate_validation.this.certificate_arn
}
```

The private hosted zone reuses the `route53_hosted_zone` module introduced in the [Setup DNS](setup_dns.md) article, this time with `private_zone = true` and a VPC association.

### ACM Certificate Unit

Now, we create a unit that calls this module and get the `domain_name` and `zone_id` from the `route53_hosted_zone` unit:
```hcl
# units/eks/acm_certificate/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/acm_certificate/?ref=${values.version}"
}

dependency "route53_hosted_zone" {
  config_path = "../route53/hosted_zone_public"
  mock_outputs = {
    domain_name = "mock.example.com"
    zone_id     = "MOCKZONEID123456"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  domain_name = dependency.route53_hosted_zone.outputs.domain_name
  zone_id     = dependency.route53_hosted_zone.outputs.zone_id
}
```

### Private Hosted Zone Unit

The private zone reuses the same `route53_hosted_zone` module from the [Setup DNS](setup_dns.md) article, this time with `private_zone = true` and a VPC association:
```hcl
# units/eks/route53/hosted_zone_private/terragrunt.hcl
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

dependency "vpc" {
  config_path = "../../../vpc"
  mock_outputs = {
    vpc_id = "mock-vpc-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  create       = true
  private_zone = true
  vpc_id       = dependency.vpc.outputs.vpc_id
  name         = local.domain_name
  comment      = values.comment
  tags = {
    environment = local.environment
  }
}
```

The domain name is assembled from `dns_config.hcl` and `environment.hcl` the same way as in the public zone unit, producing the same domain string (e.g. `argocd.dev.yourdomain.com`).

ExternalDNS will write A records into this zone once the Ingress is created.

### Integrate into EKS Stack

Add both units to the EKS stack:

```hcl
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "acm_certificate" {
  source = "${get_repo_root()}/units/eks/acm_certificate"
  path   = "eks/acm_certificate"

  values = {
    version = local.version
  }
}

unit "route53_hosted_zone_private" {
  source = "${get_repo_root()}/units/eks/route53/hosted_zone_private"
  path   = "eks/route53/hosted_zone_private"

  values = {
    version = local.version
    comment = "Managed by Terraform"
  }
}
```

## AWS Load Balancer Controller (LBC)

The LBC will watch the ArgoCD Ingress resource and will create an internal AWS Application Load Balancer (ALB) to route traffic inside the VPC.

### AWS LBC IAM Role Module

First, we create an IAM role with the required permissions and attach it to the LBC pod via [Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html).

You can find the full IAM documentation under the [Configure IAM installation guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/#configure-iam).

Here's the module:

```hcl
# modules/iam_role_aws_lbc/versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.9.1"
}

# modules/iam_role_aws_lbc/variables.tf
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "iam_policy_name" {
  description = "Name of the IAM policy to create for the AWS LBC"
  type        = string
}

variable "iam_policy_url" {
  description = "URL to the AWS LBC IAM policy JSON"
  type        = string
}

variable "iam_role_name" {
  description = "Name of the IAM role to create for the AWS LBC"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the IAM role"
  type        = map(string)
  default     = {}
}

# modules/iam_role_aws_lbc/main.tf
data "http" "aws_lbc_iam_policy" {
  url = var.iam_policy_url
}

resource "aws_iam_policy" "this" {
  name   = var.iam_policy_name
  policy = data.http.aws_lbc_iam_policy.response_body
}

resource "aws_iam_role" "this" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEksAuthToAssumeRoleForPodIdentity"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.this.arn
}

# modules/iam_role_aws_lbc/outputs.tf
output "role_arn" {
  description = "The ARN of the IAM role for the AWS LBC"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "The name of the IAM role for the AWS LBC"
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "The ARN of the IAM policy for the AWS LBC"
  value       = aws_iam_policy.this.arn
}
```

It is crucial to use these specific values for the `namespace` and `service_account` arguments as AWS LBC looks for a service account named `aws-load-balancer-controller` in the `kube-system` namespace.

### AWS LBC IAM Role Unit

The unit wraps the `iam_role_aws_lbc` module and pulls the `cluster_name` from the EKS cluster dependency. The policy and role names are prefixed with the environment so they stay unique across `dev`, `staging`, and `prod`.

```hcl
# units/eks/addons/aws_load_balancer_controller/iam_role/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_hcl = find_in_parent_folders("environment.hcl")
  environment     = read_terragrunt_config(local.environment_hcl).locals.environment
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/iam_role_aws_lbc/?ref=${values.version}"
}

dependency "eks_cluster" {
  config_path = "../../../cluster"
  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  cluster_name    = dependency.eks_cluster.outputs.cluster_name
  iam_policy_name = "${local.environment}-${values.iam_policy_name}"
  iam_policy_url  = values.iam_policy_url
  iam_role_name   = "${local.environment}-${values.iam_role_name}"
  tags            = values.tags
}
```

### AWS LBC Helm Module

We'll also create a shared Helm release module reused for all k8s addon installations:

```hcl
# modules/helm_release/versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
  required_version = ">= 1.9.1"
}

# modules/helm_release/variables.tf
variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "name" {
  description = "Name of the Helm release"
  type        = string
}

variable "repository" {
  description = "URL of the Helm chart repository"
  type        = string
}

variable "chart" {
  description = "Name of the Helm chart"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install the chart into"
  type        = string
}

variable "create_namespace" {
  description = "Create the namespace if it does not already exist"
  type        = bool
  default     = true
}

variable "helm_chart_version" {
  description = "Version of the Helm chart to install"
  type        = string
}

variable "helm_values" {
  description = "Values to pass to the Helm chart"
  type        = any
  default     = {}
}

variable "helm_set" {
  description = "Individual Helm values to set, passed as-is to the helm_release set attribute"
  type = list(object({
    name  = string
    value = string
    type  = optional(string)
  }))
  default = []
}

variable "helm_set_sensitive" {
  description = "Individual Helm values to set as sensitive, passed as-is to the helm_release set_sensitive attribute"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# modules/helm_release/main.tf
resource "helm_release" "this" {
  name             = var.name
  repository       = var.repository
  chart            = var.chart
  version          = var.helm_chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values        = [yamlencode(var.helm_values)]
  set           = var.helm_set
  set_sensitive = var.helm_set_sensitive
}

# modules/helm_release/outputs.tf
output "namespace" {
  description = "Namespace the Helm release was deployed into"
  value       = helm_release.this.namespace
}
```

### AWS LBC Helm Unit

The Helm unit installs the LBC chart into `kube-system` and passes the cluster name, region, and VPC ID so the controller knows where to provision load balancers:
```hcl
# units/eks/addons/aws_load_balancer_controller/helm/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "provider_kubernetes" {
  path = find_in_parent_folders("provider_kubernetes.hcl")
}

locals {
  region_hcl = find_in_parent_folders("region.hcl")
  region     = read_terragrunt_config(local.region_hcl).locals.region
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/helm_release/?ref=${values.version}"
}

dependency "vpc" {
  config_path = "../../../../vpc"
  mock_outputs = {
    vpc_id = "mock-vpc-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

dependency "acm_certificate" {
  config_path  = "../../../acm_certificate"
  skip_outputs = true
}

dependency "iam_role_aws_lbc" {
  config_path  = "../iam_role"
  skip_outputs = true
}

inputs = {
  cluster_name       = dependency.eks_cluster.outputs.cluster_name
  name               = "aws-load-balancer-controller"
  repository         = "https://aws.github.io/eks-charts"
  chart              = "aws-load-balancer-controller"
  namespace          = "kube-system"
  create_namespace   = false
  helm_chart_version = values.helm_chart_version
  helm_values = {
    clusterName                 = dependency.eks_cluster.outputs.cluster_name
    region                      = local.region
    vpcId                       = dependency.vpc.outputs.vpc_id
    enableServiceMutatorWebhook = values.enableServiceMutatorWebhook
  }
}
```

It declares ordering dependencies on the ACM certificate and the IAM role unit with `skip_outputs = true`.

Those units must be applied first, but their outputs are not needed here.

### Integrate into EKS Stack

Add both units to the EKS stack. The `iam_policy_url` points to the official LBC IAM policy JSON published by the kubernetes-sigs project.

```hcl
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "iam_role_aws_lbc" {
  source = "${get_repo_root()}/units/eks/addons/aws_load_balancer_controller/iam_role"
  path   = "eks/addons/aws_load_balancer_controller/iam_role"

  values = {
    version         = local.version
    iam_policy_name = "aws-load-balancer-controller-policy"
    iam_policy_url  = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.2.1/docs/install/iam_policy.json"
    iam_role_name   = "aws-load-balancer-controller"
    tags            = {}
  }
}

unit "aws_load_balancer_controller" {
  source = "${get_repo_root()}/units/eks/addons/aws_load_balancer_controller/helm"
  path   = "eks/addons/aws_load_balancer_controller/helm"

  values = {
    version                     = local.version
    helm_chart_version          = "3.2.1"
    enableServiceMutatorWebhook = false
  }
}
```

## External DNS

When the LBC creates the internal ALB, we need an A record in the private hosted zone pointing to its hostname. The `external-dns` controller automates this by watching Ingress resources and writing the records.

### External DNS IAM Role Module

We create an IAM role with Route53 permissions and attach it to the ExternalDNS pod via Pod Identity.

Here's the module:

```hcl
# modules/iam_role_external_dns/versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.9.1"
}

# modules/iam_role_external_dns/variables.tf
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "iam_policy_name" {
  description = "Name of the IAM policy to create for External DNS"
  type        = string
}

variable "iam_role_name" {
  description = "Name of the IAM role to create for External DNS"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the IAM role"
  type        = map(string)
  default     = {}
}

# modules/iam_role_external_dns/main.tf
# tfsec:ignore:aws-iam-no-policy-wildcards - official policy from external-dns docs, already scoped to hostedzone/*
resource "aws_iam_policy" "this" {
  name = var.iam_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources",
        ]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones"]
        Resource = ["*"]
      },
    ]
  })
}

resource "aws_iam_role" "this" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEksAuthToAssumeRoleForPodIdentity"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.this.arn
}

# modules/iam_role_external_dns/outputs.tf
output "role_arn" {
  description = "The ARN of the IAM role for External DNS"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "The name of the IAM role for External DNS"
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "The ARN of the IAM policy for External DNS"
  value       = aws_iam_policy.this.arn
}
```

### External DNS IAM Role Unit

The unit wraps the `iam_role_external_dns` module and pulls the `cluster_name` from the EKS cluster dependency. As with the LBC, policy and role names are prefixed with the environment.

```hcl
# units/eks/addons/external_dns/iam_role/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_hcl = find_in_parent_folders("environment.hcl")
  environment     = read_terragrunt_config(local.environment_hcl).locals.environment
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/iam_role_external_dns/?ref=${values.version}"
}

dependency "eks_cluster" {
  config_path = "../../../cluster"
  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  cluster_name    = dependency.eks_cluster.outputs.cluster_name
  iam_policy_name = "${local.environment}-${values.iam_policy_name}"
  iam_role_name   = "${local.environment}-${values.iam_role_name}"
  tags            = values.tags
}
```

### External DNS Helm Unit

The Helm unit uses the shared `helm_release` module introduced in the [LBC section](#aws-load-balancer-controller-lbc). It reads the `domain_name` from the private hosted zone and passes it as `domainFilters[0]` to scope ExternalDNS to that zone.

The `aws-zone-type = private` flag in the Helm values ensures ExternalDNS only modifies the private hosted zone and never touches the public one.

```hcl
# units/eks/addons/external_dns/helm/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "provider_kubernetes" {
  path   = find_in_parent_folders("provider_kubernetes.hcl")
  expose = true
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/helm_release/?ref=${values.version}"

  before_hook "wait_for_dns_cleanup" {
    commands = ["destroy"]
    execute  = ["sleep", "60"]
  }
}

dependency "aws_load_balancer_controller" {
  config_path  = "../../aws_load_balancer_controller/helm"
  skip_outputs = true
}

dependency "iam_role_external_dns" {
  config_path  = "../iam_role"
  skip_outputs = true
}

dependency "route53_hosted_zone_private" {
  config_path = "../../../route53/hosted_zone_private"
  mock_outputs = {
    domain_name = "mock.example.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  cluster_name       = dependency.eks_cluster.outputs.cluster_name
  name               = "external-dns"
  repository         = "https://kubernetes-sigs.github.io/external-dns/"
  chart              = "external-dns"
  namespace          = "external-dns"
  create_namespace   = true
  helm_chart_version = values.helm_chart_version
  helm_values        = values.helm_values
  helm_set = [
    {
      name  = "txtOwnerId"
      value = include.provider_kubernetes.locals.cluster_name_full
    },
    {
      name  = "txtPrefix"
      value = "%%%{record_type}-external-dns-${include.provider_kubernetes.locals.cluster_name_full}."
    },
    {
      name  = "domainFilters[0]"
      value = dependency.route53_hosted_zone_private.outputs.domain_name
    }
  ]
}
```

### Integrate into EKS Stack

Add both units to the EKS stack:

```hcl
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "iam_role_external_dns" {
  source = "${get_repo_root()}/units/eks/addons/external_dns/iam_role"
  path   = "eks/addons/external_dns/iam_role"

  values = {
    version         = local.version
    iam_policy_name = "external-dns-policy"
    iam_role_name   = "external-dns"
    tags            = {}
  }
}

unit "external_dns" {
  source = "${get_repo_root()}/units/eks/addons/external_dns/helm"
  path   = "eks/addons/external_dns/helm"

  values = {
    version            = local.version
    helm_chart_version = "1.20.0"
    helm_values = {
      sources = ["service", "ingress"]
      provider = {
        name = "aws"
      }
      registry = "txt"
      policy   = "sync"
      logLevel = "info"
      extraArgs = {
        "aws-zone-type" = "private"
      }
    }
  }
}
```

## ArgoCD

Now all the pieces are in place to install ArgoCD. Both the `helm_release` module and the `acm_certificate` module were introduced in earlier sections.

### ArgoCD Helm Unit

The unit uses the shared `helm_release` module to install the `argo-cd` chart. The `certificate-arn` and `global.domain` are read from the ACM certificate and private hosted zone dependencies and injected via `helm_set`.

`server.insecure = true` disables ArgoCD's own TLS. TLS termination is handled by the ALB using the ACM certificate instead.

Create the Helm unit:

```hcl
# units/eks/addons/argocd/helm/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "provider_kubernetes" {
  path = find_in_parent_folders("provider_kubernetes.hcl")
}

terraform {
  source = "git::git@github.com:${include.root.locals.github_username}/${include.root.locals.github_repo_name}.git//modules/helm_release/?ref=${values.version}"
}

dependency "aws_load_balancer_controller" {
  config_path  = "../../aws_load_balancer_controller/helm"
  skip_outputs = true
}

dependency "external_dns" {
  config_path  = "../../external_dns/helm"
  skip_outputs = true
}

dependency "acm_certificate" {
  config_path = "../../../acm_certificate"
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

dependency "route53_hosted_zone_private" {
  config_path = "../../../route53/hosted_zone_private"
  mock_outputs = {
    domain_name = "mock.example.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  cluster_name       = dependency.eks_cluster.outputs.cluster_name
  name               = "argocd"
  repository         = "https://argoproj.github.io/argo-helm"
  chart              = "argo-cd"
  namespace          = "argocd"
  create_namespace   = true
  helm_chart_version = values.helm_chart_version
  helm_values        = values.helm_values
  helm_set = [
    {
      name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
      value = dependency.acm_certificate.outputs.certificate_arn
    },
    {
      name  = "global.domain"
      value = dependency.route53_hosted_zone_private.outputs.domain_name
    }
  ]
}
```

### Integrate into EKS Stack

Add the unit to the EKS stack. The `helm_values` block configures the ALB ingress with `scheme = internal` so the ArgoCD endpoint is never exposed to the public internet.

```hcl
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "argocd" {
  source = "${get_repo_root()}/units/eks/addons/argocd/helm"
  path   = "eks/addons/argocd/helm"

  values = {
    version            = local.version
    helm_chart_version = "9.5.0"
    helm_values = {
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      server = {
        ingress = {
          enabled          = true
          controller       = "aws"
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"           = "internal"
            "alb.ingress.kubernetes.io/target-type"      = "ip"
            "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
            "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80}, {\"HTTPS\":443}]"
            "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
          }
          aws = {
            serviceType            = "ClusterIP"
            backendProtocolVersion = "GRPC"
          }
        }
      }
    }
  }
}
```

## Deploy the Stack

From the root of the repository, generate and apply the EKS stack for the `example` environment:

```bash
source .env
cd pipelines/examples/stacks/eks
terragrunt stack generate
terragrunt run --all apply --backend-bootstrap --non-interactive
```

Commit and push the changes:

```bash
git add .
git commit -m "add argocd pipeline"
git push origin argocd
```

Open a pull request and merge once the pipeline passes.

## Testing

The ALB is internal, so ArgoCD is not reachable from outside the VPC. We test from inside the cluster by spinning up a temporary debug pod, which runs within the VPC and can resolve the private hosted zone.

Start a debug pod:

```bash
kubectl run debug --image=curlimages/curl -it --rm --restart=Never -- sh
```

Inside the pod, run:

```bash
curl -v https://argocd.example.yourdomain.com
```

You should see:

```bash
<!doctype html><html lang="en"><head><meta charset="UTF-8"><title>Argo CD</title>...
```

## Accessing ArgoCD

ArgoCD is not reachable from the public internet. To access it from your browser, you need to be connected to the Tailscale VPN. Read the Tailscale article for setup instructions.

## Destroy the Stack

To tear down the full EKS stack, run from `pipelines/examples/stacks/eks`:

```bash
terragrunt run --all destroy --non-interactive
```
