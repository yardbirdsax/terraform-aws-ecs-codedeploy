# Deploying AWS ECS integrated with CodeDeploy using Terraform

This Terraform module will deploy an ECS cluster, service, and task definition which is integrated with AWS CodeDeploy for easily rolling out new versions of containers.

## Module Requirements

This module requires Terraform version 0.12.31 or higher. **At some point in the near future support for versions under 0.14 will be dropped.**

## Pre-requisites

* You need an AWS account that you have admin privileges on.
* You must create an ECR repository in your account. The module currently grants ECS the ability to pull images from any repository in your account; in the future this will be configurable to only allow access to specified ones.

## Full example walk-through

The following steps walk through a complete use of the module using all defaults. This will deploy things in the default VPC of your account, and this assumes that you will be deploying in US-EAST-2.

### Creating the first Docker image

- Create an ECR called `nginx-test` in your account.
  ```
  aws ecr create-repository --repository-name nginx-test
  ```

- Generate the local Docker image
  
  ```bash
  docker build . -t nginx-test:1.0 --build-arg version=1.0
  ```

- Log in to ECR in your account

  ```bash
  ACCOUNT_ID=`aws sts get-caller-identity | jq '.Account' -r`
  aws ecr get-login-password | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com
  ```

- Tag and push the image

  ```bash
  DOCKER_TAG=${ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com 
  docker tag nginx-test:1.0 $DOCKER_TAG/nginx-test:1.0
  docker push $DOCKER_TAG/nginx-test:1.0
  ```

### Deploying infrastructure

>**DO NOT do this in a production subscription.**

- Run Terraform

  ```bash
  cd examples/basic
  terraform apply -auto-approve
  ```

## Creating a second version

- Build and push a new Docker image

  ```bash
  cd ../..
  docker build . -t nginx-test:2.0 --build-arg version=2.0
  ACCOUNT_ID=`aws sts get-caller-identity | jq '.Account' -r`
  aws ecr get-login-password | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com
  DOCKER_TAG=${ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com 
  docker tag nginx-test:2.0 $DOCKER_TAG/nginx-test:2.0
  docker push $DOCKER_TAG/nginx-test:2.0
  ```

- Apply a new Terraform config with the new version

  ```bash
  terraform apply -var docker_tag=2.0
  ```

  This should only change the task definition.

- Start and monitor the CodeDeploy deployment.