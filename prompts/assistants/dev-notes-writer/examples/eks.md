# **Prerequisites**

- AWS account with billing enabled
- GitHub account
- AWS IAM permissions to manage IAM roles, VPC resources, compute resources and S3 (see `policy_arns` in the [bootstrap stack](https://github.com/ConsciousML/terragrunt-template-live-aws/blob/main/live/bootstrap/enable_tg_github_actions/terragrunt.stack.hcl) for a list of the specific IAM policies)

You’ll also need to be familiar with:

- Kubernetes ([my article](https://www.axelmendoza.com/posts/kubernetes-beginner-guide/) cf)
- Terragrunt ([my article](https://www.axelmendoza.com/posts/terraform-vs-terragrunt/) cf)

# Installation

Fork the [catalog repository](https://github.com/ConsciousML/terragrunt-template-catalog-aws), by clicking on `Use this template` button.

Choose an approriate name for the repository such a `terragrunt-template-catalog-eks` .

Clone the repository:

```yaml
git clone git@github.com:ConsciousML/terragrunt-template-catalog-eks.git
```

First, `cd` at the root of this repository:

```yaml
cd terragrunt-template-catalog-eks
```

Install mise:

```
curl https://mise.run | sh
```

Add `eksctl` to the tools to install:

```yaml
echo "eksctl = \"latest\"" >> mise.toml
```

Then, install all the tools in the `mise.toml` file:

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

For more information on how to use mise, read their [getting started guide](https://mise.jdx.dev/getting-started.html).

Authenticate to the AWS CLI using your [authentication type](https://docs.aws.amazon.com/cli/v1/userguide/cli-chap-authentication.html) of choice. Then run:

```yaml
aws configure
```

For more information, read the [AWS CLI authentication documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

# Feature: EKS Cluster TG Pipeline

Create branch:

```yaml
git checkout -b eks
```

We’ll create a EKS cluster, but first, we’ll need to create a VPC with at least two subnets in different availability zones.

EKS need a VPC with specific requirements.

Here’s a non exhaustive list of requirements:

- sufficient IP addresses for Kubernetes resources
- must have DNS hostname and DNS resolution support
- each subnet must have at least 6 ip addresses reserved for k8s
- subnets must have at least two availability zones
- to deploy load balancers, private subnets need to have the [`kubernetes.io/role/internal-elb`](http://kubernetes.io/role/internal-elb) tag with value `1`, and public subnets need the [`kubernetes.io/role/elb`](http://kubernetes.io/role/elb)  tag with value `1` .

Read [EKS networking requirements for VPC and subnets](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html) ****for the full list of VPC and subnets requirements.

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"
  
  create_vpc = true

  name = "vpc-eks"

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

This configuration creates the `vpc-eks` resource:

- with one NAT Gateway per AZ
- DNS Hostname and DNS support
- Uses IP `10.0.0.0` for the VPC with `/16` fixed bytes for the network.
- This allows to create subnets of `/24` fixed bytes allowing for 8 bytes for hosts IPs (256)
- Tag to use Load Balancers in the public and private subnet

In the `examples/region.hcl`  add the AZS for the VPC:

```hcl
locals {
  region = "eu-west-3"
  azs    = ["eu-west-3a", "eu-west-3b"] # add this line
}
```

Create a file into:

```hcl
# units/eks-vpc/terragrunt.hcl
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
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=${values.version}"
}

inputs = {
  create_vpc = values.create_vpc

  name = "${values.name}-${local.environment}"

  cidr = values.cidr
  azs = local.azs

  private_subnets = values.private_subnets
  public_subnets = values.public_subnets

  enable_nat_gateway   = values.enable_nat_gateway
  single_nat_gateway   = values.single_nat_gateway
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

Next, create an example stack using this unit:

```hcl
# examples/stacks/eks/terragrunt.stack.hcl
locals {
  # Sets the reference of the source code to:
  version = coalesce(
    get_env("GITHUB_HEAD_REF", ""), # PR branch name (only set in PRs)
    get_env("GITHUB_REF_NAME", ""), # Branch/tag name
    try(run_cmd("git", "rev-parse", "--abbrev-ref", "HEAD"), ""),
    "main" # fallback
  )
}

unit "vpc" {
  source = "${get_repo_root()}/units/vpc_eks"
  path = "vpc"

  values = {
    create_vpc = true
    version = "6.6.0"

    name = "vpc-eks"

    cidr = "10.0.0.0/16"

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
}
```

Now let’s create the EKS cluster:

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
```

We create a unit, then use the unit in `examples/stacks/eks/terragrunt.stack.hcl` stack.

Finally we apply the configuration:

```hcl
cd examples/stacks/eks
terragrunt stack generate
terragrunt stack run apply
```

To destroy you can run:

```hcl
terragrunt stack run destroy
```

Follow the [bootstrap documentation](https://github.com/ConsciousML/terragrunt-template-catalog-eks/blob/main/bootstrap/README.md) to enable CI/CD with GitHub Actions.

Now merge the PR.

# Access the Cluster

## Access Entries

In the `terraform-aws-modules/eks/aws` , using the following automatically add the user (us) as a cluster administrator through [access entry](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) (maps IAM premissions to k8s permissions):

```hcl
enable_cluster_creator_admin_permissions = true
```

This means you’ll have access to the cluster as an administrator.

To add another user, use the `access_entries` argument following the documentation of the [`aws_eks_access_entry`](https://registry.terraform.io/providers/-/aws/latest/docs/resources/eks_access_entry) and [aws_eks_policy_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) terraform resources.

Tip: the full type definition for `access_entries` is in the module's [`variables.tf`](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/variables.tf) 

More information [cluster access entry section.](https://github.com/terraform-aws-modules/terraform-aws-eks?tab=readme-ov-file#cluster-access-entry)

## Configuring `kubectl`

Create or update a `kubeconfig` file for your cluster. Replace `*region-code*` with the AWS Region that your cluster is in and replace `*my-cluster*` with the name of your cluster:

```hcl
aws eks update-kubeconfig --region region-code --name my-cluster
```

For example:

```hcl
aws eks update-kubeconfig --region eu-west-3 --name example-2-eks-cluster
```

Now, you should be able to interact with the cluster:

```hcl
k get pods -n kube-system
```

```hcl
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
