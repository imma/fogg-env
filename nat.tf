module "nat" {
  source = "module/network"

  vpc_id   = "${aws_vpc.env.id}"
  env_name = "${var.env_name}"

  env_sg        = "${aws_security_group.env.id}"
  env_public_sg = "${aws_security_group.env_public.id}"
  subnets       = ["${aws_subnet.nat.*.id}"]

  network_name    = "nat"
  interface_count = "${var.nat_interface_count}"
}

resource "aws_security_group_rule" "forward_allow_ping" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = 0
  protocol                 = "icmp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "forward_allow_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "forward_allow_ntp" {
  type                     = "ingress"
  from_port                = 123
  to_port                  = 123
  protocol                 = "udp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "forward_allow_dns_udp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "forward_allow_dns_tcp" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
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

resource "aws_security_group_rule" "forward_irc" {
  type                     = "ingress"
  from_port                = 6667
  to_port                  = 6667
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${module.nat.network_sg}"
}
