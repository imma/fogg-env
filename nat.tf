module "nat" {
  source = "module/network"

  vpc_id          = "${aws_vpc.env.id}"
  env_name        = "${var.env_name}"
  env_zone        = "${var.env_zone}"
  env_domain_name = "${var.env_domain_name}"

  networkname = "nat"

  ami_id           = "${var.nat_ami_id}"
  instance_type    = "${var.nat_instance_type}"
  instance_count   = "${var.nat_instance_count}"
  root_volume_size = "${var.nat_root_volume_size}"
}

resource "aws_security_group_rule" "forward_allow_ping" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = 0
  protocol                 = "icmp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "forward_allow_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "forward_allow_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}
