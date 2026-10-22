variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "github_user" {
  description = "Usuario de GitHub dueño del repo"
  type        = string
  default     = "flopy-cloud"
}

variable "github_repo" {
  description = "Nombre del repo que puede subir imágenes"
  type        = string
  default     = "aws-devsecops-pipeline"
}