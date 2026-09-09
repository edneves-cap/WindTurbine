output "vpc_cidr" {
  value = var.cidr_block
}

output "availability_zones" {
  value = data.aws_availability_zones.available.names
}
