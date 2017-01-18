# ECS Task Runner Terraform Module

A terraform module to schedule standalone EC2 Container Service (ECS) tasks.

* Creates a Cloudwatch scheduled event with a cron-style or rate expression.
* Provisions a lambda function that runs an ECS task definition on a specific cluster with an override for the container command.
* Targets the scheduled event at the Lambda function.
* Takes care of setting up the necessary IAM roles and policies for Lambda and Cloudwatch logging.

## Preparing and updating the Lambda function 

If you update the nodejs Lambda function code in the "lambda-task-runner" folder after you have already applied a module with Terraform, then you need to take the following steps to "re-provision" the Lambda function.

In this module folder:
```
cd lambda-task-runner
zip -9 lambda-task-runner.zip index.js
mv lambda-task-runner.zip ../
```

In the directory for the terraform environment you are provisioning:
```
terraform taint aws_cloudwatch_event_target.call_task_runner_scheduler
terraform taint aws_lambda_function.task_runner 
```

Then you can make a terraform plan and apply as you ususually would.

## TODO

1. Allow overriding task environment variables too.
2. Lambda function could be extended to poll 'describe-tasks' and look for an exit code. The function could then report a success/failure metric to the Cloudwatch logs.