variable "global_bucket" {}
variable "global_key" {}
variable "global_region" {}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.global_bucket}"
    key            = "${var.global_key}"
    region         = "${var.global_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "external" "org" {
  program = ["${var.org}"]
}

data "aws_vpc" "current" {
  id = "${aws_vpc.env.id}"
}

data "aws_availability_zones" "azs" {}

data "aws_partition" "current" {}

resource "aws_vpc" "env" {
  cidr_block                       = "${data.external.org.result["cidr_${var.env_name}"]}"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group" "env" {
  name        = "${var.env_name}"
  description = "Environment ${var.env_name}"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group_rule" "env_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.env.id}"
}

resource "aws_security_group" "env_private" {
  name        = "${var.env_name}-private"
  description = "Environment ${var.env_name} Private"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-private"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group" "env_public" {
  name        = "${var.env_name}-public"
  description = "Environment ${var.env_name} Public"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-public"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_security_group" "env_lb" {
  name        = "${var.env_name}-lb"
  description = "Environment ${var.env_name} LB"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-lb"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group_rule" "env_lb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.env_lb.id}"
}

resource "aws_security_group" "env_lb_private" {
  name        = "${var.env_name}-lb-private"
  description = "Environment ${var.env_name} LB Private"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-lb-private"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_security_group" "env_lb_public" {
  name        = "${var.env_name}-lb-public"
  description = "Environment ${var.env_name} LB Public"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-lb-public"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_internet_gateway" "env" {
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_egress_only_internet_gateway" "env" {
  vpc_id = "${aws_vpc.env.id}"
  count  = 1
}

resource "null_resource" "fake" {
  count = "${var.az_count}"

  triggers {
    meh = ""
  }
}

resource "aws_subnet" "public" {
  vpc_id                          = "${aws_vpc.env.id}"
  availability_zone               = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block                      = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.public_bits,element(coalescelist(var.public_subnets,split(" ",data.external.org.result["sys_public"])),count.index))}"
  map_public_ip_on_launch         = true
  ipv6_cidr_block                 = "${cidrsubnet(data.aws_vpc.current.ipv6_cidr_block,8,element(split(" ",data.external.org.result["sys_public_v6"]),count.index))}"
  assign_ipv6_address_on_creation = true
  count                           = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}-public"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route" "public" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.env.id}"
}

resource "aws_route" "public_v6" {
  route_table_id              = "${aws_route_table.public.id}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${aws_egress_only_internet_gateway.env.id}"
  count                       = 0
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${element(aws_subnet.public.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.public.*.id,count.index)}"
  count          = "${var.az_count}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_public" {
  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.public.*.id,count.index)}"
  count           = "${var.az_count}"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_public" {
  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${element(aws_route_table.public.*.id,count.index)}"
  count           = "${var.az_count}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-public"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_subnet" "common" {
  vpc_id                          = "${aws_vpc.env.id}"
  availability_zone               = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block                      = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.common_bits,element(coalescelist(var.common_subnets,split(" ",data.external.org.result["sys_common"])),count.index))}"
  map_public_ip_on_launch         = false
  ipv6_cidr_block                 = "${cidrsubnet(data.aws_vpc.current.ipv6_cidr_block,8,element(split(" ",data.external.org.result["sys_common_v6"]),count.index))}"
  assign_ipv6_address_on_creation = true
  count                           = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}-common"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route" "common" {
  route_table_id         = "${element(aws_route_table.common.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.env.*.id,count.index%(var.az_count*(signum(var.nat_count)-1)*-1+var.nat_count))}"
  count                  = "${var.want_nat*var.az_count}"
}

resource "aws_route" "common_v6" {
  route_table_id              = "${aws_route_table.common.id}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${aws_egress_only_internet_gateway.env.id}"
  count                       = 0
}

resource "aws_route_table_association" "common" {
  subnet_id      = "${element(aws_subnet.common.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.common.*.id,count.index)}"
  count          = "${var.az_count}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_common" {
  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.common.*.id,count.index)}"
  count           = "${var.az_count}"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_common" {
  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${element(aws_route_table.common.*.id,count.index)}"
  count           = "${var.az_count}"
}

resource "aws_route_table" "common" {
  vpc_id = "${aws_vpc.env.id}"
  count  = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}-common"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_subnet" "nat" {
  vpc_id                  = "${aws_vpc.env.id}"
  availability_zone       = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.nat_bits,element(coalescelist(var.nat_subnets,split(" ",data.external.org.result["sys_nat"])),count.index))}"
  map_public_ip_on_launch = true
  count                   = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}-nat"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route" "nat" {
  route_table_id         = "${aws_route_table.nat.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.env.id}"
}

resource "aws_route_table_association" "nat" {
  subnet_id      = "${element(aws_subnet.nat.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.nat.*.id,count.index)}"
  count          = "${var.az_count}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_nat" {
  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.nat.*.id,count.index)}"
  count           = "${var.az_count}"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_nat" {
  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${element(aws_route_table.nat.*.id,count.index)}"
  count           = "${var.az_count}"
}

resource "aws_nat_gateway" "env" {
  subnet_id     = "${element(aws_subnet.nat.*.id,count.index)}"
  allocation_id = "${element(module.nat.allocation_id,count.index)}"
  count         = "${var.want_nat*(var.az_count*(signum(var.nat_count)-1)*-1+var.nat_count)}"
}

resource "aws_route_table" "nat" {
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-nat"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route53_zone" "private" {
  name   = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${var.env_domain_name == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}"
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route53_zone_association" "associates" {
  zone_id = "${element(var.associate_zones,count.index)}"
  vpc_id  = "${aws_vpc.env.id}"
  count   = "${var.associate_count}"
}

module "efs" {
  source   = "git@github.com:imma/fogg-efs"
  efs_name = "${var.env_name}"
  vpc_id   = "${aws_vpc.env.id}"
  env_name = "${var.env_name}"
  subnets  = ["${aws_subnet.common.*.id}"]
  az_count = "${var.az_count}"
  want_efs = "${var.want_efs}"
}

resource "aws_route53_record" "efs" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "efs.${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${element(module.efs.efs_dns_names,count.index)}"]
  count   = "${var.want_efs}"
}

resource "aws_s3_bucket" "lb" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-lb"
  acl    = "private"

  depends_on = ["aws_s3_bucket.s3"]

  versioning {
    enabled = true
  }

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-s3"
    target_prefix = "log/"
  }

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "",
    "Action": "s3:PutObject",
    "Effect": "Allow",
    "Resource": "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-lb/*",
    "Principal": {
      "AWS": "arn:aws:iam::${lookup(data.external.org.result,"aws_account_${var.env_name}")}:root"
    }
  }]
}
EOF

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name = "${var.env_name}-flow-log"
}

data "aws_iam_policy_document" "flow_log" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_log" {
  name               = "${var.env_name}-flow-log"
  assume_role_policy = "${data.aws_iam_policy_document.flow_log.json}"
}

data "aws_iam_policy_document" "flow_log_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name   = "${var.env_name}-flow-log"
  role   = "${aws_iam_role.flow_log.id}"
  policy = "${data.aws_iam_policy_document.flow_log_logs.json}"
}

resource "aws_flow_log" "env" {
  log_group_name = "${aws_cloudwatch_log_group.flow_log.name}"
  iam_role_arn   = "${aws_iam_role.flow_log.arn}"
  vpc_id         = "${aws_vpc.env.id}"
  traffic_type   = "ALL"
}

resource "aws_s3_bucket" "meta" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-meta"
  acl    = "log-delivery-write"

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

resource "aws_s3_bucket" "s3" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-s3"
  acl    = "log-delivery-write"

  depends_on = ["aws_s3_bucket.meta"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-meta"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

resource "aws_s3_bucket" "ses" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-ses"
  acl    = "private"

  depends_on = ["aws_s3_bucket.s3"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "",
    "Action": "s3:PutObject",
    "Effect": "Allow",
    "Resource": "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-ses/*",
    "Principal": {
      "Service": "ses.amazonaws.com"
    },
    "Condition": {
      "StringEquals": {
        "aws:Referer": "${data.terraform_remote_state.org.aws_account_id}"
      }
    }
  }]
}
EOF

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

resource "aws_s3_bucket" "ssm" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-ssm"
  acl    = "private"

  depends_on = ["aws_s3_bucket.s3"]

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "",
    "Action": "s3:GetBucketAcl",
    "Effect": "Allow",
    "Resource": "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-ssm",
    "Principal": {
      "Service": "ssm.amazonaws.com"
    }
  },
  {
    "Sid": "",
    "Action": "s3:PutObject",
    "Effect": "Allow",
    "Resource": "arn:${data.aws_partition.current.partition}:s3:::b-${format("%.8s",sha1(data.terraform_remote_state.org.aws_account_id))}-${var.env_name}-ssm/*/accountid=${data.terraform_remote_state.org.aws_account_id}/*",
    "Principal": {
      "Service": "ssm.amazonaws.com"
    },
    "Condition": {
      "StringEquals": {
        "s3:x-amz-acl": "bucket-owner-full-control"
      }
    }
  }]
}
EOF

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

data "template_file" "key_pair_service" {
  template = "${file(var.public_key)}"
}

resource "aws_key_pair" "service" {
  public_key = "${data.template_file.key_pair_service.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_ssh_key" "service" {
  name       = "${var.env_name}"
  public_key = "${data.template_file.key_pair_service.rendered}"

  lifecycle {
    create_before_destroy = true
  }

  count = "${var.want_digitalocean}"
}

resource "packet_ssh_key" "service" {
  name       = "${var.env_name}"
  public_key = "${data.template_file.key_pair_service.rendered}"

  lifecycle {
    create_before_destroy = true
  }

  count = "${var.want_packet}"
}

resource "aws_kms_key" "env" {
  description         = "Environment ${var.env_name}"
  enable_key_rotation = true

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
    "Name"      = "${var.env_name}"
  }

  count = "${var.want_kms}"
}

resource "aws_kms_alias" "env" {
  name          = "alias/${var.env_name}"
  target_key_id = "${element(coalescelist(aws_kms_key.env.*.id,list(lookup(data.terraform_remote_state.org.kms_key_id,var.region))),0)}"
}

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = "${aws_vpc.env.id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
}

data "aws_vpc_endpoint_service" "dynamodb" {
  service = "dynamodb"
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = "${aws_vpc.env.id}"
  service_name = "${data.aws_vpc_endpoint_service.dynamodb.service_name}"
}

resource "aws_default_vpc_dhcp_options" "default" {}

resource "aws_vpc_dhcp_options" "env" {
  domain_name_servers = ["${aws_default_vpc_dhcp_options.default.domain_name_servers}"]
  domain_name         = "${aws_route53_zone.private.name}"

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
    "Name"      = "${var.env_name}"
  }
}

resource "aws_vpc_dhcp_options_association" "env" {
  vpc_id          = "${aws_vpc.env.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.env.id}"
}

resource "aws_codecommit_repository" "env" {
  repository_name = "${var.env_name}"
  description     = "Repo for ${var.env_name} env"
}

data "aws_acm_certificate" "env" {
  provider = "aws.us_east_1"
  domain   = "${aws_route53_zone.private.name}"
  statuses = ["ISSUED", "PENDING_VALIDATION"]
}

resource "aws_api_gateway_rest_api" "env" {
  name = "${var.env_name}"
}

resource "aws_api_gateway_domain_name" "env" {
  domain_name     = "${aws_route53_zone.private.name}"
  certificate_arn = "${data.aws_acm_certificate.env.arn}"
}

resource "aws_route53_record" "env_api_gateway" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    name                   = "${aws_api_gateway_domain_name.env.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.env.cloudfront_zone_id}"
    evaluate_target_health = "true"
  }
}

resource "aws_route53_record" "env_api_gateway_private" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "${aws_route53_zone.private.name}"
  type    = "A"

  alias {
    name                   = "${aws_api_gateway_domain_name.env.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.env.cloudfront_zone_id}"
    evaluate_target_health = "true"
  }
}

resource "aws_api_gateway_base_path_mapping" "env" {
  api_id      = "${aws_api_gateway_rest_api.env.id}"
  stage_name  = "live"
  domain_name = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}"
}
