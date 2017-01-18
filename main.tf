/**
 * Module: ecs-task-scheduler
 *
 * This module allows EC2 Container Service tasks to be run on a schedule.
 * The schedule is specified using scheduled Cloudwatch events. This allows
 * events to be scheduled (using cron or rate expressions) and associated with
 * a target. In this case the target is a Lambd function which can execute an
 * ECS task on a cluster.
 */

variable "stack_name" {}
variable "ecs_cluster_id" {}
variable "region" {}

/**
 * A short name to identify the job. E.g. "reindex-es-users".
 */
 variable "job_identifier" {}

/**
 * A cron or rate expression.
 * See: http://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html
 */
variable "schedule_expression" {}

/**
 * The family and revision (family:revision) or full Amazon Resource Name (ARN) of the
 * task definition to run. If a revision is not specified, the latest ACTIVE
 * revision is used.
 */
variable "ecs_task_def" {}

/**
 * The container name. Used when overriding the command. 
 */
variable "container_name" {}

/**
 * The container command to run. It should be a terraform array of strings, e.g.
 *  container_cmd = ["/app/ops/spaaza","ops:refreshDemandwareAccessTokens"]
 */
variable "container_cmd" {
  type = "list"
}



// Lambda function to run an ECS task with the AWS SDK.
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

/**
 * A rule for a cloudwatch schedule event.
 */
resource "aws_cloudwatch_event_rule" "task_runner_scheduler" {
  name = "${var.stack_name}-${var.job_identifier}"
  description = "${var.stack_name}-${var.job_identifier}-schedule"
  schedule_expression = "${var.schedule_expression}"
}

/**
 * Target the lambda function with the schedule.
 */
resource "aws_cloudwatch_event_target" "call_task_runner_scheduler" {
  rule = "${aws_cloudwatch_event_rule.task_runner_scheduler.name}"
  target_id = "${aws_lambda_function.task_runner.function_name}"
  arn = "${aws_lambda_function.task_runner.arn}"
  input = "${data.template_file.task_json.rendered}"
}

data "template_file" "task_json" {
    template = "${file("${path.module}/task.tpl")}"

    vars {
        job_identifier = "${var.job_identifier}"
        region         = "${var.region}"
        cluster        = "${var.ecs_cluster_id}"
        ecs_task_def   = "${var.ecs_task_def}"
        container_name = "${var.container_name}"
        container_cmd  = "${jsonencode(var.container_cmd)}"
    }
}

/**
 * Permission to allow Cloudwatch events to trigger the task runner
 * Lambda function.
 */
resource "aws_lambda_permission" "allow_cloudwatch_to_call_task_runner" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.task_runner.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.task_runner_scheduler.arn}"
}
