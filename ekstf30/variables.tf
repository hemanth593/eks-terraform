variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "additional_security_groups" {
  type = list(string)
}

variable "cluster_sg_rules" {
  type = list(object({
    protocol  = string
    from_port = number
    to_port   = number
  }))
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "cluster_role_arn" {
  type = string
}

variable "node_group_role_arn" {
  type = string
}

variable "cluster_tags" {
  type    = map(string)
  default = {}
}

variable "cluster_sg_tags" {
  type    = map(string)
  default = {}
}

variable "node_groups" {
  type = map(object({
    ami_id        = string
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
    tags          = map(string)
  }))
}

variable "launch_template_tags" {
  type    = map(string)
  default = {}
}

variable "asg_tags" {
  type    = map(string)
  default = {}
}
