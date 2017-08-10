variable "env_name" {}

variable "az_count" {}

variable "nat_count" {
  default = "0"
}

variable "nat_bits" {
  default = "12"
}

variable "public_bits" {
  default = "8"
}

variable "common_bits" {
  default = "8"
}

variable "env_zone" {
  default = ""
}

variable "env_domain_name" {
  default = ""
}

variable "associate_zones" {
  default = []
}

variable "associate_count" {
  default = "0"
}

variable "want_efs" {
  default = "1"
}

variable "want_nat" {
  default = "1"
}

variable "want_ipv6" {
  default = "1"
}

variable "want_digitalocean" {
  default = "0"
}

variable "public_key" {}

output "vpc_id" {
  value = "${aws_vpc.env.id}"
}

output "igw_id" {
  value = "${aws_internet_gateway.env.id}"
}

output "egw_id" {
  value = "${aws_egress_only_internet_gateway.env.id}"
}

output "private_zone_id" {
  value = "${aws_route53_zone.private.zone_id}"
}

output "private_zone_servers" {
  value = "${aws_route53_zone.private.name_servers}"
}

output "private_zone_name" {
  value = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.global.domain_name}"
}

output "sg_efs" {
  value = "${module.efs.efs_sg}"
}

output "sg_env" {
  value = "${aws_security_group.env.id}"
}

output "sg_env_private" {
  value = "${aws_security_group.env_private.id}"
}

output "sg_env_public" {
  value = "${aws_security_group.env_public.id}"
}

output "s3_bucket_prefix" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}"
}

output "s3_env_meta" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-meta"
}

output "s3_env_s3" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-s3"
}

output "s3_env_lb" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-lb"
}

output "s3_env_ses" {
  value = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-ses"
}

output "sg_env_lb" {
  value = "${aws_security_group.env_lb.id}"
}

output "sg_env_lb_private" {
  value = "${aws_security_group.env_lb_private.id}"
}

output "sg_env_lb_public" {
  value = "${aws_security_group.env_lb_public.id}"
}

output "nat_eips" {
  value = ["${aws_eip.nat.*.public_ip}"]
}

output "nat_gateways" {
  value = ["${aws_nat_gateway.env.*.id}"]
}

output "nat_subnets" {
  value = ["${aws_subnet.nat.*.id}"]
}

output "public_subnets" {
  value = ["${aws_subnet.public.*.id}"]
}

output "env_name" {
  value = "${var.env_name}"
}

output "key_name" {
  value = "${aws_key_pair.service.key_name}"
}

output "do_ssh_key" {
  value = "${digitalocean_ssh_key.service.id}"
}

output "route_tables" {
  value = ["${concat(aws_route_table.common.*.id,aws_route_table.public.*.id,aws_route_table.nat.*.id)}"]
}

output "s3_endpoint_id" {
  value = "${aws_vpc_endpoint.s3.id}"
}

output "egw_gateway" {
  value = "${aws_egress_only_internet_gateway.env.id}"
}
