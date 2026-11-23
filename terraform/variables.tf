variable "region" {
  type    = string
  default = "ca-central-1"
}

variable "bucket_name" {
  type = string
  # Bucket names are global across ALL of AWS, so this has to be unique
  default = "iqs8-homelab-velero"
}

variable "budget_email" {
  type        = string
  description = "Where budget alerts go. Set in terraform.tfvars (not committed)."
}