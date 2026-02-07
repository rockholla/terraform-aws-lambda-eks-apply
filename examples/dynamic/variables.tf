variable "supported_regions" {
  description = "Supported regions for where an EKS cluster, related VPC, and Lambda apply of the related manifest will happen"
  type        = list(string)
  default     = ["us-west-2"]
}

variable "force_apply" {
  description = "pass through to the module force_apply"
  type        = bool
  default     = false
}

variable "delete_manifest" {
  description = "If we want to remove the manifest, kubectl delete instead of kubectl apply"
  type        = bool
  default     = false
}
