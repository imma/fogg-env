data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "fn" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fn" {
  name               = "${var.env_name}-fn"
  assume_role_policy = "${data.aws_iam_policy_document.fn.json}"
}

resource "aws_api_gateway_rest_api" "env" {
  name = "${var.env_name}"
}

resource "aws_api_gateway_domain_name" "env" {
  domain_name     = "${aws_route53_zone.private.name}"
  certificate_arn = "${data.terraform_remote_state.org.wildcard_cert}"
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

locals {
  deployment_zip = ["${split("/","${path.module}/deployment.zip")}"]
}

module "fn" {
  source         = "git@github.com:imma/fogg-api-gateway//module/fn"
  function_name  = "${var.env_name}-fn"
  source_arn     = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.env.id}/*/*/*"
  role           = "${aws_iam_role.fn.arn}"
  deployment_zip = "${join("/",slice(local.deployment_zip,length(local.deployment_zip)-4,length(local.deployment_zip)))}"
  unique_prefix  = "${aws_api_gateway_rest_api.env.id}-${aws_api_gateway_rest_api.env.root_resource_id}"
}

module "env" {
  source = "git@github.com:imma/fogg-api-gateway//module/resource"

  http_method = "POST"
  api_name    = "hello"
  invoke_arn  = "${module.fn.invoke_arn}"

  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  resource_id = "${aws_api_gateway_rest_api.env.root_resource_id}"
}

resource "aws_api_gateway_base_path_mapping" "env" {
  depends_on  = ["aws_api_gateway_deployment.env"]
  api_id      = "${aws_api_gateway_rest_api.env.id}"
  stage_name  = "live"
  domain_name = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : data.terraform_remote_state.org.domain_name}"
}

resource "aws_api_gateway_deployment" "env" {
  depends_on  = ["module.env"]
  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  stage_name  = "live"
}

resource "aws_api_gateway_method_settings" "env" {
  rest_api_id = "${aws_api_gateway_rest_api.env.id}"
  stage_name  = "${aws_api_gateway_deployment.env.stage_name}"
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true
  }
}
