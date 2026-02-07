terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
  }

  provider_meta "aws" {
    user_agent = [
      "github.com/rockholla/terraform-aws-lambda-eks-apply"
    ]
  }
}
