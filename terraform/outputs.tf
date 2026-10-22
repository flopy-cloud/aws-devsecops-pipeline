output "role_arn" {
  value = aws_iam_role.github.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}