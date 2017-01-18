/**
 * Module: ecs-task-scheduler-tf/scheduled-task
 *
 * This module allows EC2 Container Service tasks to be run on a schedule.
 * The schedule is specified using scheduled Cloudwatch events. This allows
 * events to be scheduled (using cron or rate expressions) and associated with
 * a target. In this case the target is a Lambda function which can execute an
 * ECS task on a cluster.
 * 
 * The lambda function and its IAM role and policies should be created separately
 * using the 'ecs-task-scheduler-tf/base' module and then provided to this module
 * through input variables.
 */

variable "stack_name" {}
variable "ecs_cluster_id" {}
variable "region" {}

/**
 * The name and ARN of the lambda function to target.
 */
variable "lambda_function_arn" {}
variable "lambda_function_name" {}

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
  target_id = "${var.lambda_function_name}"
  arn = "${var.lambda_function_arn}"
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
  function_name = "${var.lambda_function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.task_runner_scheduler.arn}"
}
