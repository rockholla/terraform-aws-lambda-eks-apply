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
