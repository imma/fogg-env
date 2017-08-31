module "vpn" {
  source = "module/network"

  vpc_id   = "${aws_vpc.env.id}"
  env_name = "${var.env_name}"

  env_sg        = "${aws_security_group.env.id}"
  env_public_sg = "${aws_security_group.env_public.id}"
  subnets       = ["${aws_subnet.nat.*.id}"]

  network_name    = "vpn"
  interface_count = "${var.vpn_interface_count}"
  want_eip        = "${var.want_vpn_eip}"
}

resource "aws_route" "nat_vpn_eni" {
  route_table_id         = "${aws_route_table.nat.id}"
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = "${element(module.vpn.interfaces,count.index)}"
  count                  = 1
}

resource "aws_security_group_rule" "vpn_tcp" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["10.8.0.0/24"]
  security_group_id = "${aws_security_group.env.id}"
  count             = "${var.want_vpn}"
}

resource "aws_security_group_rule" "vpn_udp" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "udp"
  cidr_blocks       = ["10.8.0.0/24"]
  security_group_id = "${aws_security_group.env.id}"
  count             = "${var.want_vpn}"
}

resource "aws_security_group_rule" "vpn_ping" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["10.8.0.0/24"]
  security_group_id = "${aws_security_group.env.id}"
  count             = "${var.want_vpn}"
}
