# Input variables:

variable "r53_domain" {
  type = string
}

variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "dynamodb_tablename" {
  type = string
  default = "LambdaNet"
}

variable "aws_profile" {
  type = string
  #  default = "default"
}

# Simple AWS Lambda Terraform Example
# requires 'index.js' in the same directory
# to test: run `terraform plan`
# to deploy: run `terraform apply`

provider "aws" {
  region = var.aws_region
  version = "~> 2.0"
  profile = "default"
}

resource "aws_route53_zone" "r53zone" {
  name = var.r53_domain
  
}

# Lambdas and their accompanying zip files

data "archive_file" "lambdanet_register_zip" {
  type          = "zip"
  source_file   = "server/register.js"
  output_path   = "output/lambdanet_register.zip"
}

resource "aws_lambda_function" "LambdaNet_Register" {
  filename         = "output/lambdanet_register.zip"
  function_name    = "LambdaNet_Register"
  role             = aws_iam_role.lambdanet_iam_role.arn
  handler          = "register.handler"
  source_code_hash = data.archive_file.lambdanet_register_zip.output_base64sha256
  runtime          = "nodejs12.x"
}

data "archive_file" "lambdanet_deregister_zip" {
  type          = "zip"
  source_file   = "server/deregister.js"
  output_path   = "output/lambdanet_deregister.zip"
}

resource "aws_lambda_function" "LambdaNet_Deregister" {
  filename         = "output/lambdanet_deregister.zip"
  function_name    = "LambdaNet_Deregister"
  role             = aws_iam_role.lambdanet_iam_role.arn
  handler          = "deregister.handler"
  source_code_hash = data.archive_file.lambdanet_deregister_zip.output_base64sha256
  runtime          = "nodejs12.x"
}

data "archive_file" "lambdanet_get_zip" {
  type          = "zip"
  source_file   = "server/get.js"
  output_path   = "output/lambdanet_get.zip"
}

resource "aws_lambda_function" "LambdaNet_Get" {
  filename         = "output/lambdanet_get.zip"
  function_name    = "LambdaNet_Get"
  role             = aws_iam_role.lambdanet_iam_role.arn
  handler          = "get.handler"
  source_code_hash = data.archive_file.lambdanet_get_zip.output_base64sha256
  runtime          = "nodejs12.x"
}

# DynamoDB table

resource "aws_dynamodb_table" "lambdanet_ddb_table" {
  name = var.dynamodb_tablename
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "service"
  range_key = "location"

  attribute {
    name = "service"
    type = "S"
  }
  
  attribute {
    name = "location"
    type = "S"
  }
}

# HTTP API (from API Gateway)

resource "aws_apigatewayv2_api" "lambdanet_api" {
  name          = "LambdaNet_HTTP_API"
  protocol_type = "HTTP"
}

# HTTP API Endpoint

resource "aws_apigatewayv2_integration" "lambdanet_api_get" {
  api_id           = aws_apigatewayv2_api.lambdanet_api.id
  
  integration_type = "AWS_PROXY"
  connection_type           = "INTERNET"
  description               = "Get available services from LambdaNet"
  integration_method        = "GET"
  integration_uri           = aws_lambda_function.LambdaNet_Get.invoke_arn
  passthrough_behavior      = "WHEN_NO_MATCH"
}


# IAM Role

resource "aws_iam_role" "lambdanet_iam_role" {
  name = "LambdaNet_Lambda_Role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
	"Action": "sts:AssumeRole",
	"Principal": {
          "Service": "lambda.amazonaws.com"
	},
	"Effect": "Allow",
	"Sid": "69"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "lambdanet_iam_policy" {
  name = "LambdaNet-Policy"
  policy = data.aws_iam_policy_document.lambdanet_iam_policy_document.json
}

resource "aws_iam_role_policy_attachment" "lambdanet_attach" {
  role       = aws_iam_role.lambdanet_iam_role.name
  policy_arn = aws_iam_policy.lambdanet_iam_policy.arn
}

data "aws_iam_policy_document" "lambdanet_iam_policy_document" {
  statement {
    sid = "1"
    actions = [
      "dynamodb:BatchGet*",
      "dynamodb:PutItem",
      "dynamodb:Get*",
      "route53:ChangeResourceRecordSets",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:DescribeStream",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:CreateTable",
      "dynamodb:DescribeTable",
      "dynamodb:Delete*",
      "route53:ListResourceRecordSets",
      "dynamodb:BatchWrite*",
      "dynamodb:Update*",
      "dynamodb:DescribeReservedCapacity*",
      "dynamodb:List*",
      "dynamodb:DescribeLimits"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${aws_route53_zone.r53zone.zone_id}",
      aws_dynamodb_table.lambdanet_ddb_table.arn
    ]
  }
}
