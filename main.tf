terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnets, var.public_subnets)
    security_group_ids      = var.additional_security_groups
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = var.cluster_tags
}

locals {
  cluster_sg_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  date_suffix   = formatdate("DDMMYY", timestamp())
}

resource "aws_ec2_tag" "cluster_sg_name" {
  resource_id = local.cluster_sg_id
  key         = "Name"
  value       = "eks-cluster-sg-${var.cluster_name}-${local.date_suffix}"
}

resource "aws_security_group_rule" "cluster_sg_rules" {
  for_each = { for idx, rule in var.cluster_sg_rules : "${rule.protocol}_${rule.from_port}_${rule.to_port}" => rule }

  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  security_group_id        = local.cluster_sg_id
  source_security_group_id = local.cluster_sg_id
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnets

  instance_types = [each.value.instance_type]

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  tags = each.value.tags
}
