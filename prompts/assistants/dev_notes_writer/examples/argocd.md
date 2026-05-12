Prerequisite: [EKS Terragrunt](https://www.notion.so/EKS-Terragrunt-30d3205f20be8048a6eddd6450e4c8e4?pvs=21) 

## Overview

Here's how we will have ArgoCD available for internal teams:

1. Create a hosted zone for the subdomain in Route 53. It will be the
authoritative DNS zone for our subdomain, where all DNS records for
it will live. It outputs 4 name servers.
2. ⚠️ Manual step — Add those 4 name servers to our parent domain as NS
records in Namecheap. This delegates authority for the subdomain to
Route 53.
3. Use AWS Certificate Manager (ACM) to issue a TLS certificate for the
subdomain. ACM validates we own the domain by checking a CNAME record
we add to the hosted zone.
4. Install the AWS Load Balancer Controller (LBC) into the cluster. When
we create a k8s Ingress for ArgoCD, it provisions an Application Load Balancer (ALB) that uses the
ACM certificate to serve HTTPS traffic, and Route 53 is updated with
an Alias A record pointing the subdomain to the ALB.
5. Install the ExternalDNS controller that will update our DNS provider when we'll create an Ingress configuration (i.e it'll add the ALB hostname as an alias record to our subdomain).
6. Install ArgoCD will Helm with an Ingress to ALB.

## Route 53 Zone and ACM

To expose the ArgoCD UI publicly, we need a domain name backed by a valid
TLS certificate.

We'll use AWS Route 53 as a DNS service.

First, we'll create a subdomain on our existing domain. (If you don't have your own domain, you'll need to register one).

Then, we'll delegate DNS for our subdomain to Route53 by following the  https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html documentation.

Let's create a Route 53 hosted zone:

```hcl
resource "aws_route53_zone" "this" {
  name    = "argocd.yourdomain.com"
}
```

Then, we create the ACM ressource:

```hcl
resource "aws_acm_certificate" "this" {
  domain_name       = aws_route53_zone.this.name
  validation_method = "DNS"
}
```

Add the records of the certificate to the hosted zone records:

```hcl
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
  zone_id         = data.aws_route53_zone.this.zone_id
}
```

Wait untils the ACM certificate is issued:

```hcl
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
}
```

We output the server names of the hosted zone:

```hcl
output "name_servers" {
  description = "The list of name servers for the hosted zone (delegate these to your domain registrar)"
  value       = aws_route53_zone.this.name_servers
}
```

After applying, we retrieve the server names:

```hcl
terraform output
```

Finally, in our domain registrar (GoDaddy, Namecheap, etc.), we add 4 NS records to delegate the subdomain to Route53:

```hcl
| Type | Host | Value |
|------|------|-------|
| NS | `argocd` | `ns-123.awsdns-12.com` |
| NS | `argocd` | `ns-456.awsdns-34.net` |
| NS | `argocd` | `ns-789.awsdns-56.org` |
| NS | `argocd` | `ns-012.awsdns-78.co.uk` |
```

## AWS Load Balancer Controller (LBC)

The LBC will watch the ArgoCD Ingress resource and will create an AWS Application Load Balancer (ALB) to expose the ArgoCD UI to the public internet.

First, we create an AWS IAM role with the required permission and attach it to the LBC pod. You can find the whole documentation under the [Configure IAM installation guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/#configure-iam:~:text=Configure%20IAM-,%C2%B6,-The%20controller%20runs).

First, we create the IAM role:

```hcl
resource "aws_iam_role" "this" {
  name = "aws-load-balancer-controller"

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
}
```

Next, we get the IAM policy from an url:

```hcl
data "http" "aws_lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.2.1/docs/install/iam_policy.json"
}
```

We create the IAM policy:

```hcl
resource "aws_iam_policy" "this" {
  name   = "aws-load-balancer-controller-policy"
  policy = data.http.aws_lbc_iam_policy.response_body
}
```

We attach the policy to the IAM role:

```hcl
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
```

Finally, we use [Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) instead of IAM role for service account (IRSA). Make sure you have the [Pod Identity addon installed](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-agent-setup.html) on your EKS cluster:

```hcl
resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = "my-cluster"
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.this.arn
}
```

It is crucial to use these specific values for the `namespace` and `service_account` arguments as AWS LBC look for a service account named `aws-load-balancer-controller` in the `kube-system` namespace.

Finally, we install the AWS LBC in our cluster with helm (replace values with `<>`):

```hcl
resource "helm_release" "this" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "3.2.1"
  namespace        = "kube-system"
  create_namespace = false

  values = [yamlencode({
    clusterName = "<eks_cluster_name>"
    region      = "<aws_region>"
    vpcId       = "<vpc_id>"
  })]
}
```

## External DNS

When creating the ALB, we need to create an alias record pointing to its hostname so the hosted zone routes traffic to it.

To avoid doing it manually, we'll install the `external-dns` k8s addon to automate this step.

First, we'll create a IAM Role:

```hcl
resource "aws_iam_role" "this" {
    name = "dev-external-dns"

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
  }
```

Next, we create an IAM policy so that the `external-dns` addon can have the permissions on the Route53 resources:

```hcl
resource "aws_iam_policy" "this" {
    name = "dev-external-dns-policy"

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
```

Now, we need to attach the policy to the IAM role:

```hcl
resource "aws_iam_role_policy_attachment" "this" {
    role       = aws_iam_role.this.name
    policy_arn = aws_iam_policy.this.arn
  }
```

Similarly to the previous section, we use Pod Identity to attribute the IAM role to the `external-dns` :

```hcl
resource "aws_eks_pod_identity_association" "this" {
    cluster_name    = "<eks_cluster_name>"
    namespace       = "external-dns"
    service_account = "external-dns"
    role_arn        = aws_iam_role.this.arn
  }
```

Finally, we install the `external-dns` addon with Helm (replacing `<argocd.yourdomain.com>` and `<cluster_name>`:

```hcl
resource "helm_release" "this" {
    name             = "external-dns"
    repository       = "https://kubernetes-sigs.github.io/external-dns/"
    chart            = "external-dns"
    version          = "1.20.0"
    namespace        = "external-dns"
    create_namespace = true

    values = [yamlencode({
      sources       = ["service", "ingress"]
      domainFilters = ["<argocd.yourdomain.com>"]
      provider = {
        name = "aws"
      }
      registry = "txt"
    })]

    set = [
      {
        name  = "txtOwnerId"
        value = "<cluster_name>"
      }
    ]
  }
```

## ArgoCD

Now all the pieces are in place to install ArgoCD with Helm (replace `<argocd.yourdomain.com>`:

```hcl
resource "helm_release" "this" {
    name             = "argocd"
    repository       = "https://argoproj.github.io/argo-helm"
    chart            = "argo-cd"
    version          = "9.5.0"
    namespace        = "argocd"
    create_namespace = true

    values = [yamlencode({
      global = {
        domain = "<argocd.yourdomain.com>"
      }
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
            "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
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
    })]

    set = [
      {
        name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
        value = "<acm_certificate_arn>"
      }
    ]
  }
```

# Test

```bash
kubectl run debug --image=curlimages/curl -it --rm --restart=Never -- sh
```

Inside the Pod, run:

```bash
curl -v https://argocd.example.axelmendoza.com
```

You should see:

```bash
<!doctype html><html lang="en"><head><meta charset="UTF-8"><title>Argo CD</title><base href="/"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" type="image/png" href="assets/favicon/favicon-32x32.png" sizes="32x32"/><link rel="icon" type="image/png" href="assets/favicon/favicon-16x16.png" sizes="16x16"/><link href="assets/fonts.css" rel="stylesheet"><script defer="defer" src="main.f722093d5c2155369128.js"></script></head><body><noscript><p>Your browser does not support JavaScript. Please enable JavaScript to view the site. Alternatively, Argo CD can be used with the <a href="https://argoproj.github.io/argo-cd/cli_installation/">Argo CD CLI</a>.</p></noscript><div id="app"></div></body><script defer="defer" src="extensions.js"></script></html>
```
