# Using CodeDeploy with ECS

This repo documents my learning how to use ECS with AWS CodeDeploy.

## Pre-requisites

* You need an AWS account that you have admin privileges on.
* You need to create an ECR repository in your account named `nginx-test`.

  ```bash
  aws ecr create-repository --repository-name nginx-test
  ```

## Creating the first Docker image

- Generate the local Docker image
  
  ```bash
  docker build . -t nginx-test:1.0 --build-arg version=2.0
  ```

- Log in to ECR in your account

  ```bash
  $(aws ecr get-login --no-include-email)
  ```

- Tag and push the image

  ```bash
  DOCKER_TAG=`aws sts get-caller-identity | jq '.Account' -r`.dkr.ecr.us-east-2.amazonaws.com 
  docker tag nginx-test:1.0 $DOCKER_TAG/nginx-test:1.0
  docker push $DOCKER_TAG/nginx-test:1.0
  ```

## Deploying infrastructure

>**DO NOT do this in a production subscription.**

- Run Terraform

  ```bash
  cd terraform
  terraform apply -auto-approve
  ```

## Creating a second version

- Build and push a new Docker image

  ```bash
  cd ..
  docker build . -t nginx-test:2.0 --build-arg version=2.0
  DOCKER_TAG=`aws sts get-caller-identity | jq '.Account' -r`.dkr.ecr.us-east-2.amazonaws.com 
  docker tag nginx-test:2.0 $DOCKER_TAG/nginx-test:2.0
  $(aws ecr get-login --no-include-email)
  docker push $DOCKER_TAG/nginx-test:2.0
  ```

- Apply a new Terraform config with the new version

  ```bash
  cd terraform
  reset && terraform apply -var docker_tag=2.0
  ```

  This should only change the task definition.

- Start and monitor the CodeDeploy deployment.