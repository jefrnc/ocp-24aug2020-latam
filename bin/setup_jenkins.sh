#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git shared.na.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# DO NOT FORGET TO PASS '-n ${GUID}-jenkins to ALL commands!!'
# You do not want to set up things in the wrong project.

buffout=$(oc get dc jenkins --ignore-not-found=true -n ${GUID}-jenkins | grep -v NAME | awk '{print $1}')

echo "Start Jenkins..."
if [[ -z ${buffout} ]];then 
  oc new-app --name=jenkins --template=jenkins-persistent --param ENABLE_OAUTH=true --param VOLUME_CAPACITY=2Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true -n ${GUID}-jenkins
fi
while (true); do 
  buffout=$(oc get dc jenkins -n ${GUID}-jenkins | grep -v NAME | awk '{print $1}')
  if [[ ! -z ${buffout} ]]; then
    oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=2Gi,cpu=1 -n ${GUID}-jenkins
    break
  fi
  sleep 10
done


# Create custom agent container image with skopeo.
# Build config must be called 'jenkins-agent-appdev' for the test below to succeed


ocpbuilds=$(oc get build | grep -c "jenkins-agent-appdev.*Complete")
if [[ $ocpbuilds -eq 0 ]]; then
    export JENKINS_AGENT=jenkins-agent-appdev
      oc new-build  -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
        USER root\nRUN yum -y install skopeo && yum clean all\n
        USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins
fi


# Create Secret with credentials to access the private repository
# You may hardcode your user id and password here because
# this shell scripts lives in a private repository
# Passing it from Jenkins would show it in the Jenkins Log

oc create secret generic gitea-secret --from-literal=username=jose.franco-semperti.com --from-literal=password=redhat123! -n ${GUID}-jenkins


# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
# Build config has to be called 'tasks-pipeline'.
# Make sure you use your secret to access the repository

echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "tasks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: ${REPO}
      contextDir: "openshift-tasks"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: Jenkinsfile
kind: List
metadata: []" | oc create -f - -n ${GUID}-jenkins


oc set build-secret --source bc/tasks-pipeline gitea-secret -n ${GUID}-jenkins


# Set up ConfigMap with Jenkins Agent definition
oc create -f ./manifests/agent-cm.yaml -n ${GUID}-jenkins

# ========================================
# No changes are necessary below this line
# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done

# Make sure that Jenkins Agent Build Pod has finished building
while : ; do
  echo "Checking if Jenkins Agent Build Pod has finished building..."
  AVAILABLE_REPLICAS=$(oc get pod jenkins-agent-appdev-1-build -n ${GUID}-jenkins -o=jsonpath='{.status.phase}')
  if [[ "$AVAILABLE_REPLICAS" == "Succeeded" ]]; then
    echo "...Yes. Jenkins Agent Build Pod has finished."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done