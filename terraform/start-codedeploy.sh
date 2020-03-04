#!/usr/bin/env bash

error_exit() {
  echo "$1" 1>&2
  exit 1
}

usage () {
  cat <<EOM
USAGE: start-codedeploy.sh <application name> <group name> <S3 bucket name> <object name>
EOM
}

if [[ -z $1 ]]; then
  usage
  error_exit "One or more required arguments have not been specified."
fi
if [[ -z $2 ]]; then
  usage
  error_exit "One or more required arguments have not been specified."
fi
if [[ -z $3 ]]; then
  usage
  error_exit "One or more required arguments have not been specified."
fi
if [[ -z $4 ]]; then
  usage
  error_exit "One or more required arguments have not been specified."
fi

RESULT=`aws deploy create-deployment --application-name $1 --s3-location bucket=$3,key=$4,bundleType=YAML --deployment-group-name $2`
if [ "$?" != "0" ]; then
    error_exit "Could not start CodeDeploy deployment. Exiting."
else
    echo "Deployment started successfully."
fi

STATUS_IN_PROGRESS="InProgress"

DEPLOYMENT_ID=`echo $RESULT | jq '.deploymentId' -r`
DEPLOYMENT_STATUS="$STATUS_IN_PROGRESS"
while [ "$DEPLOYMENT_STATUS" == "$STATUS_IN_PROGRESS" ]; do
  sleep 10
  echo "  Checking deployment status."
  DEPLOYMENT_STATUS=`aws deploy get-deployment --deployment-id $DEPLOYMENT_ID | jq '.deploymentInfo.status' -r`
  if [ "$DEPLOYMENT_STATUS" == "$STATUS_IN_PROGRESS" ]; then
      echo "  Deployment is still in progress, waiting..."
  fi
done

if [ "$DEPLOYMENT_STATUS" != "Succeeded" ]; then
  error_exit "Deployment failed, please review output in AWS console."
else
  echo "Deployment succeeded."
fi