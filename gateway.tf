resource "aws_api_gateway_rest_api" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
}
