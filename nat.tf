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

data "template_file" "nat_user_data_service" {
  template = "${file(var.nat_user_data)}"

  vars {
    vpc_cidr = "${data.aws_vpc.current.cidr_block}"
    env      = "${varenv_name}"
  }
}

resource "aws_instance" "nat" {
  ami           = "${coalesce(var.nat_ami_id,data.aws_ami.block.image_id)}"
  instance_type = "${var.nat_instance_type}"
  count         = "${var.nat_instance_count}"

  key_name             = "${aws_key_pair.service.key_name}"
  user_data            = "${data.template_file.nat_user_data_service.rendered}"
  iam_instance_profile = "${var.env_name}-nat"

  vpc_security_group_ids      = ["${list(aws_security_group.env.id,aws_security_group.env_public.id)}"]
  subnet_id                   = "${element(aws_subnet.public.*.id,count.index)}"
  associate_public_ip_address = true

  lifecycle {
    ignore_changes = ["disable_api_termination", "ami", "ephemeral_block_device", "user_data", "subnet_id"]
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "${element(var.nat_root_volume_size,count.index)}"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdb"
    virtual_name = "ephemeral0"
    no_device    = ""
  }

  ephemeral_block_device {
    device_name  = "/dev/sdc"
    virtual_name = "ephemeral1"
    no_device    = ""
  }

  ephemeral_block_device {
    device_name  = "/dev/sdd"
    virtual_name = "ephemeral2"
    no_device    = ""
  }

  ephemeral_block_device {
    device_name  = "/dev/sde"
    virtual_name = "ephemeral3"
    no_device    = ""
  }

  volume_tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route53_record" "nat" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "nat.${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}" /*"*/
  type    = "A"
  ttl     = "60"
  records = ["${aws_instance.nat.private_ip}"]
  count   = "${var.nat_instance_count}"
}
