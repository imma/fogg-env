variable "network_name" {}
variable "user_data" {}

variable "vpc_id" {}
variable "env_name" {}
variable "env_zone" {}
variable "env_domain_name" {}

variable "eips" {
  default = []
}

variable "key_name" {}

variable "env_sg" {}

variable "env_public_sg" {}

variable "domain_name" {}

variable "private_zone_id" {}

variable "subnets" {
  default = []
}

variable "ami_id" {
  default = ""
}

variable "instance_type" {
  default = "t2.nano"
}

variable "instance_count" {
  default = 0
}

variable "root_volume_size" {
  default = [40]
}

output "instances" {
  value = ["${aws_instance.network.*.id}"]
}

output "network_sg" {
  value = "${aws_security_group.network.id}"
}
