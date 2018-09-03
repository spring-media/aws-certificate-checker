output "function_name" {
  description = "The unique name of your Lambda Function."
  value       = "${module.lambda.function_name}"
}

output "arn" {
  description = "The Amazon Resource Name (ARN) identifying your Lambda Function."
  value       = "${module.lambda.arn}"
}

output "invoke_arn" {
  description = "The ARN to be used for invoking Lambda Function from API Gateway - to be used in aws_api_gateway_integration's uri"
  value       = "${module.lambda.invoke_arn}"
}