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

resource "aws_ec2_tag" "cluster_sg_tags" {
  for_each = var.cluster_sg_tags

  resource_id = local.cluster_sg_id
  key         = each.key
  value       = each.value
}

resource "aws_security_group_rule" "cluster_sg_rules" {
  for_each = { for idx, rule in var.cluster_sg_rules : "${rule.protocol}_${rule.from_port}_${rule.to_port}" => rule }

  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  security_group_id        = local.cluster_sg_id
  source_security_group_id = local.cluster_sg_id

  depends_on = [aws_ec2_tag.cluster_sg_name, aws_ec2_tag.cluster_sg_tags]
}

data "aws_eks_cluster" "main" {
  name = aws_eks_cluster.main.name
}

resource "aws_launch_template" "node_group" {
  for_each = var.node_groups

  name          = "${var.cluster_name}-lt"
  image_id      = each.value.ami_id
  instance_type = each.value.instance_type

  vpc_security_group_ids = concat([local.cluster_sg_id], var.additional_security_groups)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_protocol_ipv6          = "enabled"
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = var.launch_template_tags
  }

  user_data = base64encode(<<-EOF
[settings.kubernetes]
"cluster-name" = "${data.aws_eks_cluster.main.name}"
"api-server" = "${data.aws_eks_cluster.main.endpoint}"
"cluster-certificate" = "${data.aws_eks_cluster.main.certificate_authority[0].data}"
"cluster-dns-ip" = "${cidrhost(data.aws_eks_cluster.main.kubernetes_network_config[0].service_ipv4_cidr, 10)}"
[settings.kubernetes.node-labels]
"eks.amazonaws.com/nodegroup-image" = "${each.value.ami_id}"
"eks.amazonaws.com/capacityType" = "ON_DEMAND"
"eks.amazonaws.com/nodegroup" = "${each.key}"
[settings.network]
https-proxy = "http://proxy.ebiz.verizon.com:9290"
no-proxy = ["localhost", ".api.aws", "127.0.0.1", "169.254.169.254","172.20.0.1","10.100.0.1", ".eks.amazonaws.com","autoscaling.us-east-1.amazonaws.com", "ec2.us-east-1.amazonaws.com", "sts.us-east-1.amazonaws.com", "s3.us-east-1.amazonaws.com", "elasticfilesystem.us-east-1.amazonaws.com", "ebiz.verizon.com", ".verizon.com", ".vzwcorp.com", ".vzbi.com" ]
[settings.dns]
name-servers = ["127.0.0.1", "169.254.169.253"]
search-list = ["ebiz.verizon.com","verizon.com","vpc.verizon.com","vzbi.com","tdc.vzwcorp.com","sdc.vzwcorp.com","odc.vzwcorp.com"]
EOF
  )
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  launch_template {
    id      = aws_launch_template.node_group[each.key].id
    version = "$Latest"
  }

  tags = each.value.tags
}

data "aws_autoscaling_groups" "node_group" {
  for_each = var.node_groups

  filter {
    name   = "tag:eks:nodegroup-name"
    values = [each.key]
  }

  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }

  depends_on = [aws_eks_node_group.main]
}

resource "aws_autoscaling_group_tag" "node_group" {
  for_each = merge([
    for ng_key, ng_value in var.node_groups : {
      for tag_key, tag_value in var.asg_tags :
      "${ng_key}-${tag_key}" => {
        asg_name  = data.aws_autoscaling_groups.node_group[ng_key].names[0]
        tag_key   = tag_key
        tag_value = tag_value
      }
    }
  ]...)

  autoscaling_group_name = each.value.asg_name

  tag {
    key                 = each.value.tag_key
    value               = each.value.tag_value
    propagate_at_launch = true
  }
}
