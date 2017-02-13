# ecs-kit
ECS, ALB (ELBv2), RDS and Cloud Formation reference with a small bash script for workflow

Table of contents
=================

  * [Laptop Dependencies](#laptop-dependencies)
  * [EC2 Dependencies](#ec2-dependencies)
  * [AWS Services](#aws-services)
  * [Getting Started](#getting-started)
	  * [Stack Usage](#stack-usage)
  * [Architecture](#architecture)
  * [Motivation](#motivation)


## <a name="laptop-dependencies"> Laptop Dependencies

 1. bash (Mac or Linux)
 2. aws-cli >=1.11.20


## <a name="ec2-dependencies"> EC2 Dependencies

*See* https://raw.githubusercontent.com/marshyski/ecs-kit/master/userdata.sh

 1. RHEL 7
 2. awscli (Optional)
 3. awslogs agent (Optional)
 4. ecs agent


## <a name="aws-services"> AWS Services

 - ALB
 - Auto Scaling Group
 - CloudFormation
 - CloudWatch
 - EC2
 - ECS
 - IAM
 - RDS
 - Route53
 - SNS Topic


## <a name="getting-started"> Getting Started

*This assumes you have VPC, Security Groups, IAM Certs, KeyPair, SNS Topic and Route53 Zones created*

 1. Create ECS Cluster manually by adding just clicking create cluster and entering name `<app name>-<environment>`
 2. Create CloudWatch Log Group `<app name>-<environment>`

**cft-ecs.json**

 - Change `ClusterName` helloworld-* to `<app name>-<environment>`
 - Setup `InstanceProfile` for ecsInstanceRole http://docs.aws.amazon.com/AmazonECS/latest/developerguide/instance_IAM_role.html
 - Fill out params sections for each environment or just dev to get started
 - Under `UserData` change location of where your user-data script is hosted. I recommend S3 by installing awscli first in `UserData`.

**userdata.sh**

 - Enter http proxies in locations if needed
 - Change any logic for app config
 - Add additional installations before systemctl commands

**task-definition.json**

 - Change path to `conf` and `log`
 - Change `name` from helloworld to app name
 - Change `image` to location of Docker image
 - Tweak other values as needed

**cft-db.json**

 - Change `ClusterName` helloworld-* to `<app name>-<environment>`
 - Fill out params sections for each environment or just dev to get started

**stack**

 - Change STACK variable to the app name
 - Update ENVIRONMENT variable with additional environments

#### <a name="stack-usage"> Stack Usage

    $ ./stack
    
      Stack Name: helloworld
    
      ./stack create  [dev qa prod] [db] - Create stack from cft-ecs.json
      ./stack delete  [dev qa prod] [db] - Delete stack name helloworld
      ./stack update  [dev qa prod]      - Update stack from version or latest
    
      you can override latest version for create and update
      ./stack update dev 0.0.1
    
      Database command example, database will be altered by cft-db.json
      ./stack create dev db
      ./stack delete dev db
    
      Example
      ./stack create dev db  # Create DB
      ./stack create dev     # Create Web / App Environment


## <a name="architecture"> Architecture


## <a name="motivation"> Motivation

 - Update application version quickly
 - Quicker refresh of EC2 instances with new AMIs
 - Use only minimal tools and AWS services for logging, metrics, alarms, etc.
 - Bootstrap microservices to run on EC2 Container Service and Application Load Balancer