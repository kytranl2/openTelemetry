output "ecs_cluster_id" {
  value = aws_ecs_cluster.cluster.id
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}

# outputs.tf

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.otel_config_fs.id
}

output "efs_access_point_id" {
  description = "ID of the EFS access point"
  value       = aws_efs_access_point.otel_config_ap.id
}
