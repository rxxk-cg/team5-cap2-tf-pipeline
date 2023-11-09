variable "vpc_filter" {
  type        = string
  description = "VPC Filter to create the EC1 cluster in"
  default     = "rxxkk8s-vpc"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where cluster needs to be created"
}

variable "input_private_subnetid" {
  type        = list
  description = "List of PRIVATE Subnetid which needs to pass on [sub1, sub2, sub3]"
}

variable "input_pub_subnetid" {
  type        = list
  description = "List of PUBLIC Subnetid which needs to pass on [sub1, sub2, sub3]"
}

variable "primary_region" {
  type        = string
  description = "Provide the region in which cluster will be deployed"
  default = "us-west-2"
}

variable "access_key" {
  type        = string
  description = "Provide the access key via env"
  sensitive   = true
}

variable "secret_key" {
  type        = string
  description = "Provide the secret_key via env"
  sensitive   = true
}

variable "ecr_repo" {
  type        = string
  description = "Provide the ECR Repo where image needs to pulled down"
}

variable "run_string" {
  type        = string
  description = "Provide a random string which is unique"
}

variable "latest-Tag" {
  type        = string
  description = "ECR image latest tag"
  default = "latest"
}
