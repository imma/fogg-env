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
    env      = "${var.env_name}"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_instance" "nat" {
  ami           = "${coalesce(var.nat_ami_id,data.aws_ami.block.image_id)}"
  instance_type = "${var.nat_instance_type}"
  count         = "${var.nat_instance_count}"

  key_name             = "${aws_key_pair.service.key_name}"
  user_data            = "${data.template_file.nat_user_data_service.rendered}"
  iam_instance_profile = "${var.env_name}-nat"

  vpc_security_group_ids      = ["${list(aws_security_group.env.id,aws_security_group.env_public.id,aws_security_group.nat.id)}"]
  subnet_id                   = "${element(aws_subnet.nat.*.id,count.index)}"
  associate_public_ip_address = true
  source_dest_check           = false

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

resource "aws_eip_association" "nat" {
  instance_id   = "${element(aws_instance.nat.*.id,count.index)}"
  allocation_id = "${element(aws_eip.nat.*.id,count.index)}"
  count         = "${var.nat_instance_count}"
}

resource "aws_security_group" "nat" {
  name        = "${var.env_name}-nat"
  description = "Service ${var.env_name}-nat"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group_rule" "nat_allow_ping" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = 0
  protocol                 = "icmp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${aws_security_group.nat.id}"
}

resource "aws_security_group_rule" "nat_allow_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${aws_security_group.nat.id}"
}

resource "aws_security_group_rule" "nat_allow_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.env.id}"
  security_group_id        = "${aws_security_group.nat.id}"
}

resource "aws_route53_record" "nat" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "nat${count.index+1}.${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}" /*"*/
  type    = "A"
  ttl     = "60"
  records = ["${aws_instance.nat.private_ip}"]
  count   = "${var.nat_instance_count}"
}

data "aws_iam_policy_document" "nat" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_instance_profile" "service" {
  name = "${var.env_name}-nat"
  role = "${aws_iam_role.nat.name}"
}

resource "aws_iam_role" "nat" {
  name               = "${var.env_name}-nat"
  assume_role_policy = "${data.aws_iam_policy_document.nat.json}"
}

resource "aws_iam_role_policy_attachment" "lambda_exec" {
  role       = "${aws_iam_role.nat.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = "${aws_iam_role.nat.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = "${aws_iam_role.nat.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs-container" {
  role       = "${aws_iam_role.nat.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy_attachment" "cc_ro" {
  role       = "${aws_iam_role.nat.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm-agent" {
  role       = "${aws_iam_role.nat.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "ssm-ro" {
  role       = "${aws_iam_role.nat.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}
