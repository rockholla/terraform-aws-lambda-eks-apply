terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
    utility = {
      source  = "frontiersgg/utility"
      version = "0.3.0"
    }
  }

  provider_meta "aws" {
    user_agent = [
      "github.com/rockholla/terraform-aws-lambda-eks-apply"
    ]
  }
}
