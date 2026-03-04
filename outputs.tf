output "cluster_id" {
  value = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  value = local.cluster_sg_id
}

output "cluster_security_group_name" {
  value = "eks-cluster-sg-${var.cluster_name}-${local.date_suffix}"
}

output "node_groups" {
  value = { for k, v in aws_eks_node_group.main : k => v.id }
}
