module "vpn" {
  source = "module/network"

  vpc_id          = "${aws_vpc.env.id}"
  env_name        = "${var.env_name}"
  env_zone        = "${var.env_zone}"
  env_domain_name = "${var.env_domain_name}"
  az_count        = "${var.az_count}"

  eips            = ["${aws_eip.vpn.*.id}"]
  key_name        = "${aws_key_pair.service.key_name}"
  env_sg          = "${aws_security_group.env.id}"
  env_public_sg   = "${aws_security_group.env_public.id}"
  domain_name     = "${data.terraform_remote_state.org.domain_name}"
  private_zone_id = "${aws_route53_zone.private.zone_id}"
  subnets         = ["${aws_subnet.nat.*.id}"]

  network_name = "vpn"

  ami_id           = "${var.vpn_ami_id}"
  instance_type    = "${var.vpn_instance_type}"
  root_volume_size = "${var.vpn_root_volume_size}"
  user_data        = "${var.vpn_user_data}"
  instance_count   = "${var.want_vpn}"
  interface_count  = "${var.vpn_interface_count}"
}

resource "aws_eip" "vpn" {
  vpc   = true
  count = "${var.want_vpn*var.az_count}"
}

resource "aws_security_group_rule" "public_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${module.vpn.network_sg}"
  count             = "${var.want_vpn}"
}

resource "aws_security_group_rule" "openvpn_udp" {
  type              = "ingress"
  from_port         = 1194
  to_port           = 1194
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${module.vpn.network_sg}"
  count             = "${var.want_vpn}"
}

resource "aws_security_group_rule" "openvpn_tcp" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${module.vpn.network_sg}"
  count             = "${var.want_vpn}"
}

resource "aws_route" "nat_vpn" {
  route_table_id         = "${aws_route_table.nat.id}"
  destination_cidr_block = "10.8.0.0/24"
  instance_id            = "${element(module.vpn.instances,count.index)}"
  count                  = "${var.want_vpn*var.az_count}"
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
