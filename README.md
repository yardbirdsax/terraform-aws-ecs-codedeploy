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
  docker build . -t nginx-test:1.0
  ```

- Log in to ECR in your account

  ```bash
  $(aws ecr get-login --no-include-email)
  ```

- Tag and push the image

  ```bash
  DOCKER_TAG=`aws sts get-caller-identity | jq '.Account' -r`.dkr.ecr.us-east-2.amazonaws.com; docker tag nginx-test:1.0 $DOCKER_TAG/nginx-test:1.0
  docker push $DOCKER_TAG
  ```

## Deploying infrastructure

>**DO NOT do this in a production subscription.**

- Run Terraform

  ```bash
  cd terraform
  terraform apply -auto-approve
  ```