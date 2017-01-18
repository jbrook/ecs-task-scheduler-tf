# AWS ECS Task Runner Terraform Module

Allows scheduling standalone AWS EC2 Container Service (ECS) tasks with
Terraform. There are two modules:

1. A [base](./base/main.tf) module to provision shared resources - a generic
lambda function to run AWS ECS tasks and it's associated IAM role and policies.
2. A [scheduled-task](./scheduled-task/main.tf) module to provision indivdual
scheduled tasks.
    * Creates a Cloudwatch scheduled event with a cron-style or rate expression.
    * Targets the scheduled event at the Lambda function with the arguments necessary to run the specified ECS task.

## Usage Example

```
/**
 * Shared resources to be used by ECS scheduled jobs.
 * A lambda function and it's IAM role and policies.
 */
module "ecs_task_scheduler_base_resources" {
  source = "git::ssh://git@github.com/jbrook/ecs-task-scheduler-tf.git//base"
  stack_name = "${var.stack_name}"
  ecs_cluster_id = "${var.ecs_cluster_id}"
}

/**
 * Periodically runs a job
 */
module "schedule_dw_access_token_refresh" {
  source = "git::ssh://git@github.com/jbrook/ecs-task-scheduler-tf.git//scheduled-task"
  job_identifier = "my-job"
  ecs_task_def = "<task def ARN or name:revision"
  stack_name = "${var.stack_name}"
  region = "${var.region}"
  ecs_cluster_id = "${module.core-vpc.ecs_cluster_id}"
  schedule_expression = "rate(10 minutes)"
  container_name = "my-container" # needs to match the container you want to run in the task-def
  container_cmd = ["echo","'Hello, World!'"]
  lambda_function_name = "${module.ecs_task_scheduler_base_resources.lambda_function_name}"
  lambda_function_arn = "${module.ecs_task_scheduler_base_resources.lambda_function_arn}"
}
```

## Preparing and updating the Lambda function 

If you update the nodejs Lambda function code in the "base/lambda-task-runner" folder after you have already applied a module with Terraform, then you need to take the following steps to "re-provision" the Lambda function.

In this module folder:
```
cd lambda-task-runner
zip -9 lambda-task-runner.zip index.js
mv lambda-task-runner.zip ../
```

In the directory for the terraform environment you are provisioning (the resource names will actually be different (have a look at 'terraform state list'):
```
terraform taint aws_cloudwatch_event_target.call_task_runner_scheduler
terraform taint aws_lambda_function.task_runner 
```

Then you can make a terraform plan and apply as you ususually would.

## TODO

1. Allow overriding task environment variables too.
2. Lambda function could be extended to poll 'describe-tasks' and look for an exit code. The function could then report a success/failure metric to the Cloudwatch logs.
