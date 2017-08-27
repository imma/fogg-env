data "aws_ami" "block" {
  most_recent = true

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Block"
    values = ["block-ubuntu-*"]
  }

  owners = ["self"]
}

data "template_file" "user_data_service" {
  template = "${file(var.user_data)}"

  vars {
    vpc_cidr = "${data.aws_vpc.current.cidr_block}"
    env      = "${var.env_name}"
  }
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "current" {
  id = "${var.vpc_id}"
}

resource "aws_network_interface" "network" {
  subnet_id         = "${element(var.subnets,count.index)}"
  source_dest_check = false
  count             = "${var.interface_count}"

  tags {
    "Name"      = "${var.env_name}-network-${var.network_name}"
    "Env"       = "${var.env_name}"
    "App"       = "network"
    "Service"   = "${var.network_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_eip" "network" {
  vpc   = true
  count = "${var.interface_count}"
}

resource "aws_eip_association" "network" {
  network_interface_id = "${lookup(aws_network_interface.network.*.id,count.index)}"
  allocation_id        = "${element(aws_eip.network.network.*id,count.index)}"
  count                = "${var.interface_count}"
}

resource "aws_security_group" "network" {
  name        = "${var.env_name}-network-${var.network_name}"
  description = "Service ${var.env_name}-network-${var.network_name}"
  vpc_id      = "${data.aws_vpc.current.id}"
  count       = "${signum(var.instance_count)}"

  tags {
    "Name"      = "${var.env_name}-${var.network_name}"
    "Env"       = "${var.env_name}"
    "App"       = "network"
    "Service"   = "${var.network_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_network_interface_sg_attachment" "env" {
  security_group_id    = "${var.env_sg}"
  network_interface_id = "${element(aws_network_interface.network.*.id,count.index)}"
  count                = "${var.interface_count}"
}

resource "aws_network_interface_sg_attachment" "env_public" {
  security_group_id    = "${var.env_public_sg}"
  network_interface_id = "${element(aws_network_interface.network.*.id,count.index)}"
  count                = "${var.interface_count}"
}

resource "aws_network_interface_sg_attachment" "env_network" {
  security_group_id    = "${aws_security_group.network.id}"
  network_interface_id = "${element(aws_network_interface.network.*.id,count.index)}"
  count                = "${var.interface_count}"
}
