module "vpn" {
  source = "module/network"

  vpc_id          = "${aws_vpc.env.id}"
  env_name        = "${var.env_name}"
  env_zone        = "${var.env_zone}"
  env_domain_name = "${var.env_domain_name}"

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
  instance_count   = "${var.want_vpn}"
  root_volume_size = "${var.vpn_root_volume_size}"
  user_data        = "${var.vpn_user_data}"
}

resource "aws_eip" "vpn" {
  vpc   = true
  count = "${var.want_vpn*var.az_count}"
}

resource "aws_security_group_rule" "openvpn_udp" {
  type                     = "ingress"
  from_port                = 1194
  to_port                  = 1194
  protocol                 = "udp"
  source_security_group_id = "0.0.0.0/24"
  security_group_id        = "${module.nat.network_sg}"
}

resource "aws_security_group_rule" "openvpn_tcp" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "0.0.0.0/24"
  security_group_id        = "${module.nat.network_sg}"
}
