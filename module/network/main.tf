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

resource "aws_instance" "network" {
  ami           = "${coalesce(var.ami_id,data.aws_ami.block.image_id)}"
  instance_type = "${var.instance_type}"
  count         = "${var.instance_count}"

  key_name             = "${var.key_name}"
  user_data            = "${data.template_file.user_data_service.rendered}"
  iam_instance_profile = "${var.env_name}-${var.network_name}"

  vpc_security_group_ids      = ["${list(var.env_sg,var.env_public_sg,aws_security_group.network.id)}"]
  subnet_id                   = "${element(var.subnets,count.index)}"
  associate_public_ip_address = true
  source_dest_check           = false

  lifecycle {
    ignore_changes = ["disable_api_terminetworkion", "ami", "ephemeral_block_device", "user_data", "subnet_id"]
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "${element(var.root_volume_size,count.index)}"
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
    "Name"      = "${var.env_name}-${var.network_name}"
    "Env"       = "${var.env_name}"
    "App"       = "network"
    "Service"   = "${var.network_name}"
    "ManagedBy" = "terraform"
  }

  tags {
    "Name"      = "${var.env_name}-${var.network_name}"
    "Env"       = "${var.env_name}"
    "App"       = "network"
    "Service"   = "${var.network_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_eip_association" "network" {
  instance_id   = "${element(aws_instance.network.*.id,count.index)}"
  allocation_id = "${element(var.eips,count.index)}"
  count         = "${var.instance_count}"
}

resource "aws_security_group" "network" {
  name        = "${var.env_name}-netowrk-${var.network_name}"
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

resource "aws_route53_record" "network" {
  zone_id = "${var.private_zone_id}"
  name    = "${var.network_name}${count.index+1}.${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : var.domain_name}" /*"*/
  type    = "A"
  ttl     = "60"
  records = ["${aws_instance.network.private_ip}"]
  count   = "${var.instance_count}"
}

data "aws_iam_policy_document" "network" {
  count = "${signum(var.instance_count)}"

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

resource "aws_iam_instance_profile" "network" {
  name  = "${var.env_name}-${var.network_name}"
  role  = "${aws_iam_role.network.name}"
  count = "${signum(var.instance_count)}"
}

resource "aws_iam_role" "network" {
  name               = "${var.env_name}-${var.network_name}"
  assume_role_policy = "${data.aws_iam_policy_document.network.json}"
  count              = "${signum(var.instance_count)}"
}

resource "aws_iam_role_policy_attachment" "lambda_exec" {
  role       = "${aws_iam_role.network.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
  count      = "${signum(var.instance_count)}"
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = "${aws_iam_role.network.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  count      = "${signum(var.instance_count)}"
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = "${aws_iam_role.network.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  count      = "${signum(var.instance_count)}"
}

resource "aws_iam_role_policy_attachment" "ecs-container" {
  role       = "${aws_iam_role.network.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
  count      = "${signum(var.instance_count)}"
}

resource "aws_iam_role_policy_attachment" "cc_ro" {
  role       = "${aws_iam_role.network.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"
  count      = "${signum(var.instance_count)}"
}

resource "aws_iam_role_policy_attachment" "ssm-agent" {
  role       = "${aws_iam_role.network.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  count      = "${signum(var.instance_count)}"
}

resource "aws_iam_role_policy_attachment" "ssm-ro" {
  role       = "${aws_iam_role.network.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  count      = "${signum(var.instance_count)}"
}
