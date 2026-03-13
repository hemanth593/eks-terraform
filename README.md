# EKS Cluster Terraform

Terraform configuration for deploying a production-ready Amazon EKS cluster with managed node groups.

## Features

- **Private EKS Cluster**: Endpoint accessible only within VPC
- **IPv6 Support**: Kubernetes network configured for IPv6
- **Encryption**: Secrets encrypted using AWS KMS
- **Logging**: All control plane logs enabled (API, audit, authenticator, controller manager, scheduler)
- **Managed Add-ons**: VPC CNI, kube-proxy, GuardDuty agent, node monitoring, pod identity agent
- **Custom Node Groups**: Launch templates with IMDSv2 enforcement and custom user data
- **Auto Scaling**: Configurable ASG with custom tags

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Existing VPC with private and public subnets
- IAM roles for EKS cluster and node groups
- KMS key for secrets encryption

## Project Structure

```
eks-terraform/
└── eks-cluster/
    ├── main.tf              # Main EKS resources
    ├── variables.tf         # Input variables
    ├── outputs.tf           # Output values
    └── terraform.tfvars.json # Variable values (not committed)
```

## Usage

### 1. Configure Variables

Create a `terraform.tfvars.json` file:

```json
{
  "aws_region": "us-east-1",
  "aws_account_id": "123456789012",
  "cluster_name": "my-eks-cluster",
  "kubernetes_version": "1.28",
  "vpc_id": "vpc-xxxxx",
  "private_subnets": ["subnet-xxxxx", "subnet-yyyyy"],
  "public_subnets": ["subnet-zzzzz", "subnet-aaaaa"],
  "cluster_role_arn": "arn:aws:iam::123456789012:role/eks-cluster-role",
  "node_group_role_arn": "arn:aws:iam::123456789012:role/eks-node-role",
  "kms_key_arn": "arn:aws:kms:us-east-1:123456789012:key/xxxxx",
  "additional_security_groups": [],
  "cluster_sg_rules": [],
  "node_groups": {
    "default": {
      "ami_id": "ami-xxxxx",
      "instance_type": "t3.medium",
      "min_size": 1,
      "max_size": 3,
      "desired_size": 2,
      "tags": {}
    }
  }
}
```

### 2. Deploy

```bash
cd eks-cluster
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --name <cluster-name> --region <aws-region>
kubectl get nodes
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| aws_region | AWS region | string | yes |
| cluster_name | EKS cluster name | string | yes |
| kubernetes_version | Kubernetes version | string | yes |
| vpc_id | VPC ID | string | yes |
| private_subnets | Private subnet IDs | list(string) | yes |
| public_subnets | Public subnet IDs | list(string) | yes |
| cluster_role_arn | EKS cluster IAM role ARN | string | yes |
| node_group_role_arn | Node group IAM role ARN | string | yes |
| kms_key_arn | KMS key ARN for encryption | string | yes |
| node_groups | Node group configurations | map(object) | yes |
| additional_security_groups | Additional security groups | list(string) | no |
| cluster_sg_rules | Custom security group rules | list(object) | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_endpoint | EKS cluster endpoint |
| cluster_security_group_id | Cluster security group ID |
| node_groups | Node group IDs |

## Security Considerations

- Cluster endpoint is private-only (no public access)
- IMDSv2 enforced on all nodes
- Secrets encrypted with KMS
- All control plane logs enabled
- Security group rules customizable

## Notes

- The configuration includes proxy settings specific to Verizon network. Modify the `user_data` section in launch templates if deploying elsewhere.
- External DNS and Metrics Server installation via `null_resource` may need adjustment based on your environment.

## License

MIT
