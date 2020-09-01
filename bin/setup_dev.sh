#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Tasks Development Environment in project ${GUID}-tasks-dev"

# Set up Dev Project
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-tasks-dev

# Set up Dev Application
#fix with GUID enviroment
oc apply -f manifests/tasks-cm-dev.yaml -n ${GUID}-tasks-dev
oc apply -f manifests/tasks-dc-dev.yaml -n ${GUID}-tasks-dev
oc apply -f manifests/tasks-svc-dev.yaml -n ${GUID}-tasks-dev
oc apply -f manifests/tasks-route-dev.yaml -n ${GUID}-tasks-dev


#cat manifests/tasks-cm-dev.yaml | sed  "s/GUID/${GUID}/g" | oc apply -f - -n ${GUID}-tasks-dev
#cat manifests/tasks-dc-dev.yaml | sed  "s/GUID/${GUID}/g" | oc apply -f - -n ${GUID}-tasks-dev
#cat manifests/tasks-svc-dev.yaml | sed  "s/GUID/${GUID}/g" | oc apply -f - -n ${GUID}-tasks-dev
#cat manifests/tasks-route-dev.yaml | sed  "s/GUID/${GUID}/g" | oc apply -f - -n ${GUID}-tasks-dev

# Set up Dev Build Config
#fix with GUID enviroment
oc apply -f manifests/tasks-is-dev.yaml -n ${GUID}-tasks-dev
oc apply -f manifests/tasks-bc-dev.yaml -n ${GUID}-tasks-dev

#cat manifests/tasks-is-dev.yaml | sed  "s/GUID/${GUID}/g" | oc apply -f - -n ${GUID}-tasks-dev
#cat manifests/tasks-bc-dev.yaml | sed  "s/GUID/${GUID}/g" | oc apply -f - -n ${GUID}-tasks-dev