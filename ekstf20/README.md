# EKS Cluster Terraform Configuration

This Terraform configuration creates an Amazon EKS cluster with managed node groups, custom security group rules, launch templates, and comprehensive tagging.

## Features

- **EKS Cluster**: Creates an EKS cluster with specified Kubernetes version
- **Dynamic Security Groups**: Fetches and configures AWS auto-created cluster security group with custom self-referencing rules
- **Launch Templates**: Creates launch templates for node groups with custom AMI, instance type, and metadata configuration
- **Node Groups**: Supports multiple managed node groups deployed in private subnets
- **Auto Scaling Group Tagging**: Automatically tags ASGs created by EKS node groups
- **JSON-Based Configuration**: All values are defined in `terraform.tfvars.json` for easy management

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Existing IAM roles:
  - EKS cluster role: `sre-eks-cluster-role`
  - EKS node group role: `sre-eks-nodegroup-role`
- Existing VPC with private and public subnets
- Existing security groups for additional cluster access

## File Structure

```
.
├── main.tf                    # Main Terraform resources
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── terraform.tfvars.json      # Configuration values (JSON format)
└── README.md                  # This file
```

## Configuration

All configuration is managed through `terraform.tfvars.json`. Key sections:

### Network Configuration
- VPC ID
- Private subnets (for node groups)
- Public subnets (for cluster endpoints)
- Additional security groups

### Cluster Configuration
- Cluster name
- Kubernetes version
- IAM role ARNs
- Cluster tags

### Security Group Rules
Self-referencing ingress rules for the auto-created cluster security group:
- TCP: 8080, 8081, 443, 53, 1025-65535
- UDP: 53, 1053

### Node Groups
Each node group includes:
- AMI ID
- Instance type
- Scaling configuration (min, max, desired)
- Custom tags

### Launch Template
- Metadata options (IMDSv2 required, hop limit 2)
- Custom userdata with proxy and DNS settings
- Resource tags

## Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review Configuration

Edit `terraform.tfvars.json` to match your environment:
- Update AWS account ID and region
- Verify VPC and subnet IDs
- Confirm security group IDs
- Adjust node group settings

### 3. Validate Configuration

```bash
terraform validate
```

### 4. Plan Deployment

```bash
terraform plan
```

Review the planned changes carefully.

### 5. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 6. Verify Deployment

```bash
# Update kubeconfig
aws eks update-kubeconfig --name sre-pagidh-test --region us-east-1

# Verify cluster
kubectl get nodes
```

## Outputs

After successful deployment:
- `cluster_id`: EKS cluster ID
- `cluster_endpoint`: EKS cluster API endpoint
- `cluster_security_group_id`: Auto-created cluster security group ID
- `cluster_security_group_name`: Renamed security group name
- `node_groups`: Map of node group IDs

## Adding Node Groups

To add additional node groups, update `terraform.tfvars.json`:

```json
"node_groups": {
  "pagidh-ng": { ... },
  "new-ng": {
    "ami_id": "ami-0ecaafb1786bbc080",
    "instance_type": "c6a.2xlarge",
    "min_size": 1,
    "max_size": 5,
    "desired_size": 3,
    "tags": {
      "NodeGroup": "new-ng",
      "Role": "App",
      "Vsad": "K0XV",
      "Owner": "pagidh@amazon.com",
      "Env": "NONPROD",
      "UserId": "pagidh"
    }
  }
}
```

Then run `terraform apply`.

## Modifying Security Group Rules

To add/remove security group rules, edit the `cluster_sg_rules` array in `terraform.tfvars.json`:

```json
"cluster_sg_rules": [
  { "protocol": "tcp", "from_port": 9090, "to_port": 9090 }
]
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted to confirm.

## Important Notes

- Node groups are deployed in **private subnets only**
- Launch template uses **IMDSv2 (token required)** for enhanced security
- Cluster security group is **auto-created by AWS** and dynamically tagged
- ASG tags are **propagated at launch** to EC2 instances
- All configuration values must be in `terraform.tfvars.json` (no hardcoded values)

## Troubleshooting

### Issue: Node group fails to create
- Verify IAM role has required policies attached
- Check subnet IDs are correct and in the same VPC
- Ensure AMI ID is valid for the region

### Issue: Security group rules not applied
- Verify cluster is created successfully first
- Check that cluster_sg_rules format is correct in JSON

### Issue: ASG tags not appearing
- ASG tags are applied after node group creation
- Wait a few minutes and check again
- Verify asg_tags are defined in terraform.tfvars.json

## Support

For issues or questions, contact: pagidh@amazon.com
