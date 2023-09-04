output "id_1" {
  value = aws_subnet.private.id
}

output "id_2" {
  value = aws_subnet.private_1.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}