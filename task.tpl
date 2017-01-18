{
  "job_identifier": "${job_identifier}",
  "region": "${region}",
  "cluster": "${cluster}",
  "ecs_task_def": "${ecs_task_def}",
  "overrides": {
    "containerOverrides": [
      {
        "name": "${container_name}",
        "command": ${container_cmd}
      }
    ]
  }
}
