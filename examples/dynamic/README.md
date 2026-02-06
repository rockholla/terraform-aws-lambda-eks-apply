# Dynamic Example

Meant to demonstrate (and test) against scenarios of being particularly dynamic in Terraform:

* EKS clusters provisioned with `for_each` across more than one region
* Initial applies that can leverage this module in that scenario w/o requiring follow-up applies
* Testing as many dynamic inputs as we can to make sure we don't encounter the dreaded "not known until after apply" cases
