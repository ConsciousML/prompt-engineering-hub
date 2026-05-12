# Overview

We need a reproducible, version-controlled pipeline to provision an EKS cluster on AWS. Rather than managing Terraform modules directly, we wrap everything in Terragrunt units and stacks so the same pipeline can be promoted across environments without duplicating configuration.

# Components

- **VPC:** two private and two public subnets across separate AZs, with NAT Gateways per AZ and the EKS-required load balancer tags on each subnet tier.
- **EKS Cluster:** managed Kubernetes control plane sourced from `terraform-aws-modules/eks`, connected to the VPC's private subnets with core add-ons (CoreDNS, kube-proxy, vpc-cni, pod-identity-agent).
- **Access Entry:** maps IAM identities to Kubernetes RBAC permissions without touching the `aws-auth` ConfigMap.
- **Terragrunt Unit:** a parameterized wrapper around a Terraform module, sourced once and reused across stacks.
- **Terragrunt Stack:** composes the VPC and cluster units into a single deployable pipeline with auto-wired dependencies.

# Prerequisites

- AWS account with billing enabled
- GitHub account
- `AdministratorAccess` AWS IAM permissions

You'll also need to be familiar with:

- [Kubernetes](https://www.axelmendoza.com/posts/kubernetes-beginner-guide/)
- [Terragrunt](https://www.axelmendoza.com/posts/terraform-vs-terragrunt/)

# Installation

Fork the [catalog repository](https://github.com/ConsciousML/terragrunt-template-catalog-aws), by clicking on `Use this template` button.

Choose an approriate name for the repository such a `terragrunt-template-catalog-eks` .

Clone the repository:

```yaml
git clone git@github.com:ConsciousML/terragrunt-template-catalog-eks.git
```

First, `cd` at the root of this repository:

```yaml
cd terragrunt-template-catalog-eks
```

Install mise:

```
curl https://mise.run | MISE_VERSION=v2026.4.0 sh
```

Then, install all the tools in the `mise.toml` file:

```
mise trust
mise install
```

Finally, run the following to automatically activate mise when starting a shell:

- For zsh:

```
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc && source ~/.zshrc
```

- For bash:

```
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc && source ~/.bashrc
```

For more information on how to use mise, read their [getting started guide](https://mise.jdx.dev/getting-started.html).

Authenticate to the AWS CLI using your [authentication type](https://docs.aws.amazon.com/cli/v1/userguide/cli-chap-authentication.html) of choice. Then run:

```yaml
aws configure
```

For more information, read the [AWS CLI authentication documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

# Feature: EKS Cluster TG Pipeline

Create branch:

```yaml
git checkout -b eks
```

We'll create a EKS cluster, but first, we'll need to create a VPC with at least two subnets in different availability zones.

EKS need a VPC with specific requirements.

Here's a non exhaustive list of requirements:

- sufficient IP addresses for Kubernetes resources
- must have DNS hostname and DNS resolution support
- each subnet must have at least 6 ip addresses reserved for k8s
- subnets must have at least two availability zones
- to deploy load balancers, private subnets need to have the [`kubernetes.io/role/internal-elb`](http://kubernetes.io/role/internal-elb) tag with value `1`, and public subnets need the [`kubernetes.io/role/elb`](http://kubernetes.io/role/elb)  tag with value `1` .

Read [EKS networking requirements for VPC and subnets](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html) for the full list of VPC and subnets requirements.

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"
  
  create_vpc = true

  name = "vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  one_nat_gateway_per_az = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
```

This configuration creates the `vpc` resource:

- with one NAT Gateway per AZ
- DNS Hostname and DNS support
- Uses IP `10.0.0.0` for the VPC with `/16` fixed bytes for the network.
- This allows to create subnets of `/24` fixed bytes allowing for 8 bytes for hosts IPs (256)
- Tag to use Load Balancers in the public and private subnet

In `pipelines/region.hcl` add the AZs for the VPC:

```hcl
locals {
  region = "eu-west-3"
  azs    = ["eu-west-3a", "eu-west-3b"] # add this line
}
```

Create the VPC unit:

```hcl
# units/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment_hcl = find_in_parent_folders("environment.hcl")
  environment     = read_terragrunt_config(local.environment_hcl).locals.environment

  region_hcl    = find_in_parent_folders("region.hcl")
  region_locals = read_terragrunt_config(local.region_hcl).locals
  region        = local.region_locals.region
  azs           = local.region_locals.azs

  vpc_cidr = read_terragrunt_config(find_in_parent_folders("vpc.hcl")).locals.vpc_cidr
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=${values.version}"
}

inputs = {
  create_vpc = values.create_vpc

  name = "${values.name}-${local.environment}"

  cidr = local.vpc_cidr
  azs  = local.azs

  private_subnets = values.private_subnets
  public_subnets  = values.public_subnets

  enable_nat_gateway     = values.enable_nat_gateway
  single_nat_gateway     = values.single_nat_gateway
  one_nat_gateway_per_az = values.one_nat_gateway_per_az

  enable_dns_hostnames = values.enable_dns_hostnames
  enable_dns_support   = values.enable_dns_support

  public_subnet_tags = values.public_subnet_tags

  private_subnet_tags = values.private_subnet_tags

  tags = {
    environment = "${local.environment}"
  }
}
```

Next, create a test stack using this unit:

```hcl
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
locals {
  version = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals.version
}

unit "vpc" {
  source = "${get_repo_root()}/units/vpc"
  path   = "vpc"

  values = {
    create_vpc = true
    version    = "6.6.0"

    name = "vpc"

    # For production, use at least 3 subnets
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
    public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

    enable_nat_gateway     = true
    single_nat_gateway     = false
    one_nat_gateway_per_az = true

    enable_dns_hostnames = true
    enable_dns_support   = true

    public_subnet_tags = {
      "kubernetes.io/role/elb" = 1
    }

    private_subnet_tags = {
      "kubernetes.io/role/internal-elb" = 1
    }
  }
}
```

Here's the terraform code for creating an EKS cluster:

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"
  
  name               = "eks-cluster"
  kubernetes_version = "1.35"
  
  endpoint_public_access = true
  
  # Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true
  
  vpc_id     = "vpc-1234556abcdef"
  subnet_ids = ["subnet-abcde012", "subnet-bcde012a", "subnet-fghi345a"]
  
  # EKS Provisioned Control Plane configuration
  control_plane_scaling_config = {
    tier = "standard"
  }
  
  # More info:
  # https://docs.aws.amazon.com/eks/latest/userguide/workloads-add-ons-available-eks.html
  addons = {
    coredns                = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy             = {}
    vpc-cni                = {
      before_compute = true
    }
  }
  
  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    example = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      
      # Use cheapest config for testing purposes
      instance_types = ["t3.medium"]

      min_size     = 2
      max_size     = 10
      desired_size = 2
    }
  }
  
  # Disable EKS Auto mode
  compute_config = {
    enabled = false
  }
}
```

Create the EKS cluster unit:

```hcl
# units/eks/cluster/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  cluster_hcl       = find_in_parent_folders("cluster_name_env.hcl")
  cluster_config    = read_terragrunt_config(local.cluster_hcl)
  cluster_name_full = local.cluster_config.locals.cluster_name_full
  environment       = local.cluster_config.locals.environment
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=${values.version}"
}

dependency "vpc" {
  config_path = "../../vpc"
  mock_outputs = {
    vpc_id          = "mock_vpc_id"
    private_subnets = ["mock_subnet_id_1", "mock_subnet_id_2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "graph", "destroy"]
}

inputs = {
  name = local.cluster_name_full

  kubernetes_version = values.kubernetes_version

  endpoint_public_access = values.endpoint_public_access

  # Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = values.enable_cluster_creator_admin_permissions

  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  # EKS Provisioned Control Plane configuration
  control_plane_scaling_config = values.control_plane_scaling_config

  # More info:
  # https://docs.aws.amazon.com/eks/latest/userguide/workloads-add-ons-available-eks.html
  addons = values.addons

  # EKS Managed Node Group(s)
  eks_managed_node_groups = values.eks_managed_node_groups

  # Disable EKS Auto mode
  compute_config = values.compute_config

  tags = {
    environment = "${local.environment}"
  }
}
```

Add the cluster unit to the test stack:

```hcl
# pipelines/examples/stacks/eks/terragrunt.stack.hcl
unit "cluster" {
  source = "${get_repo_root()}/units/eks/cluster"
  path   = "eks/cluster"

  values = {
    version = "21.15.1"

    kubernetes_version = "1.35"

    endpoint_public_access = true

    enable_cluster_creator_admin_permissions = true

    control_plane_scaling_config = {
      tier = "standard"
    }

    addons = {
      coredns = {}
      eks-pod-identity-agent = {
        before_compute = true
      }
      kube-proxy = {}
      vpc-cni = {
        before_compute = true
      }
    }

    eks_managed_node_groups = {
      example = {
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.medium"]

        min_size     = 2
        max_size     = 10
        desired_size = 2
      }
    }

    compute_config = {
      enabled = false
    }
  }
}
```

Finally, apply the configuration:

```bash
source .env
cd pipelines/examples/stacks/eks
terragrunt stack generate
terragrunt run --all apply --backend-bootstrap --non-interactive
```

Follow the [bootstrap documentation](https://github.com/ConsciousML/terragrunt-template-catalog-eks/blob/main/bootstrap/README.md) to enable CI/CD with GitHub Actions.

Now merge the PR.

# Access the Cluster

## Access Entries

In the `terraform-aws-modules/eks/aws` module, using the following adds our IAM user as a cluster administrator through [access entry](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) (it maps IAM permissions to k8s permissions):

```hcl
enable_cluster_creator_admin_permissions = true
```

This means you'll have access to the cluster as an administrator.

To add another user, use the `access_entries` argument following the documentation of the [`aws_eks_access_entry`](https://registry.terraform.io/providers/-/aws/latest/docs/resources/eks_access_entry) and [aws_eks_policy_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) terraform resources.

Tip: the full type definition for `access_entries` is in the module's [`variables.tf`](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/variables.tf)

More information [cluster access entry section.](https://github.com/terraform-aws-modules/terraform-aws-eks?tab=readme-ov-file#cluster-access-entry)

## Configuring `kubectl`

Create or update a `kubeconfig` file for your cluster (replace `<region-code>` and `<cluster-name>`):

```bash
aws eks update-kubeconfig --region <region-code> --name <cluster-name>
```

For example:

```bash
aws eks update-kubeconfig --region eu-west-3 --name example-eks-cluster
```

Now, you should be able to interact with the cluster:

```bash
kubectl get pods -n kube-system
```

```text
NAME                           READY   STATUS    RESTARTS   AGE
aws-node-59ld8                 2/2     Running   0          41m
aws-node-5bvc4                 2/2     Running   0          41m
coredns-845b86cddf-pg8hk       1/1     Running   0          40m
coredns-845b86cddf-vngdb       1/1     Running   0          40m
eks-pod-identity-agent-9pq6k   1/1     Running   0          41m
eks-pod-identity-agent-fzfk9   1/1     Running   0          41m
kube-proxy-khhsj               1/1     Running   0          40m
kube-proxy-pvh7h               1/1     Running   0          40m
```

# Destroy the EKS

To destroy (cwd in `pipelines/examples/stacks/eks`):

```bash
terragrunt run --all destroy --non-interactive
```
