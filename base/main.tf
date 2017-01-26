/**
 * Module: ecs-task-scheduler-tf/base
 *
 * This module is a base module to provision shared resources that will be used
 * when scheduling ECS tasks. This base module is intended to be used with
 * ecs-task-scheduler/scheduled-task. The scheduled-task companion module could
 * be used multiple times in a single terraform environment but it does not make
 * provision generic resources like the lambda function and it's IAM role and
 * policies multiple times. Instead they are created by this module and can then
 * be passed on to scheduled-task modules.
 */


variable "stack_name" {}
variable "ecs_cluster_id" {}

/**
 * Lambda function to run an ECS task with the AWS SDK.
 */
resource "aws_lambda_function" "task_runner" {
  function_name = "${var.stack_name}-ECSTaskRunner"
  filename = "${path.module}/lambda-task-runner.zip"
  runtime = "nodejs4.3"
  timeout = 30
  description = "Runs an ECS task with specified overrides"
  role = "${aws_iam_role.task_runner_execution.arn}"
  handler = "index.handler"
  environment {
    variables = {
      SOME_VAR = "SOME_VALUE"
    }
  }
  lifecycle {
    # Attempt to workaround - https://github.com/hashicorp/terraform/issues/7613
    ignore_changes = ["filename"]
  }
}

/**
 * Execution role - a role that will allow the Lambda function
 * to be executed and to run ECS tasks.
 */
resource "aws_iam_role" "task_runner_execution" {
  name = "${var.stack_name}-task-runner-execution"
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
      "Sid": ""
    }
  ]
}
EOF
}

/**
 * Policy document for running ECS tasks on this specific cluster.
 */
data "aws_iam_policy_document" "run_ecs_task_policy_document" {

  statement {
    sid = "RunTasksOnECSCluster"
    actions = [
      "ecs:RunTask",
    ]
    resources = [ "*" ] // We could restrict to a specific task family if we wanted.
    condition {
      test = "ArnEquals"
      variable = "ecs:cluster"
      values = ["${var.ecs_cluster_id}"]
    }
  }

  statement = {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
        "arn:aws:logs:*:*:*"
    ]
  }

}

/**
 * Policy allows our task runner-Lambda function to run
 * ECS tasks on this cluster and log to Cloudwatch.
 */
resource "aws_iam_policy" "run_ecs_task_policy" {
  name = "${var.stack_name}-task-runner-execution-ecs-execution-policy"
  description = "Policy to allow task-runner to run ECS tasks and log to Cloudwatch"
  path = "/"
  policy = "${data.aws_iam_policy_document.run_ecs_task_policy_document.json}"
}

/**
 * Attach the policy to the IAM role.
 */
resource "aws_iam_role_policy_attachment" "run_ecs_task_policy" {
  role = "${aws_iam_role.task_runner_execution.name}"
  policy_arn = "${aws_iam_policy.run_ecs_task_policy.arn}"
}

output "lambda_function_name" {
  value = "${aws_lambda_function.task_runner.function_name}"
}

output "lambda_function_arn" {
  value = "${aws_lambda_function.task_runner.arn}"
}

