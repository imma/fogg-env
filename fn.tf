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

module "fn" {
  source         = "git@github.com:imma/fogg-api-gateway//module/fn"
  function_name  = "${var.env_name}-fn"
  source_arn     = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.env.id}/*/*/*"
  role           = "${aws_iam_role.fn.arn}"
  deployment_zip = "${path.module}/deployment.zip"
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

resource "aws_api_gateway_deployment" "env" {
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
