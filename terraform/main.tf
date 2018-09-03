module "lambda" {
  source        = "github.com/spring-media/terraform-aws//lambda"
  name          = "scheduled"
  function_name = "certificate_checker"
  s3_bucket     = "${var.s3_bucket}"
  s3_key        = "${var.version}/certificate_checker.zip"
