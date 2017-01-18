var AWS = require('aws-sdk')
var ecs = new AWS.ECS();

exports.handler = (events, context) => {
    /*
    {
      "job_identifier": "${job_identifier}",
      "region": "${region}",
      "cluster": "${cluster}",
      "ecs_task_def": "${ecs_task_def}",
      "overrides": {
        "containerOverrides": [
          {
            "name": "${container_name}",
            "command": "${container_cmd}"
          }
        ]
      }
    }
    */
    
  console.log(events)
  var ecs_task_def = events.ecs_task_def
  var exec_region  = events.region || 'undefined'
  var cluster      = events.cluster || 'undefined'
  var overrides    = events.overrides || 'undefined'
  console.log(ecs_task_def, exec_region)
  var params = {
      taskDefinition: ecs_task_def,
      cluster: cluster,
      overrides: overrides
  }
  ecs.runTask(params, function(err, data) {
      if (err) console.log(err, err.stack); // an error occurred
      else     console.log(data);           // successful response 
      context.done(err, data)
  })
    
}
