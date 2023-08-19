#!/usr/bin/env bash

# Install OpenShift GitOps operator
oc apply -k https://github.com/redhat-cop/gitops-catalog/openshift-gitops-operator/operator/overlays/latest

# Install OpenShift Pipelines operator
oc apply -k https://github.com/redhat-cop/gitops-catalog/openshift-pipelines-operator/overlays/latest

# Install RHACS operator
oc apply -k https://github.com/redhat-cop/gitops-catalog/advanced-cluster-security-operator/operator/overlays/stable
sleep 30
# Wait for CRDs to be installed before applying central and securedcluster instances
oc apply -k https://github.com/redhat-cop/gitops-catalog/advanced-cluster-security-operator/instance/overlays/default
sleep 30

# Extract ingress cert
SECRET=$(oc get secret -l certificate-type=apiserver -n openshift-ingress -o name)
oc extract ${SECRET} -n openshift-ingress

# Update custom cert and recycle central
oc -n stackrox create secret tls central-default-tls-cert --cert tls.crt --key tls.key
CENTRALPOD=$(oc get pods -l app=central -o name -n stackrox)
oc delete ${CENTRALPOD} -n stackrox
rm -rf tls.crt tls.key

# Replace old route URLs
BASEDOMAIN="$(oc get route -n openshift-console console -o json | jq -r '.spec.host' | sed 's/^console-openshift-console.apps.//g')"
EL="el-event-listener-acs-policies-stackrox.apps.${BASEDOMAIN}"
CENTRAL="central-stackrox.apps.${BASEDOMAIN}"
sed -i "/^\([[:space:]]*value: \).*/s//\1${EL}/" app/pipeline/kustomization.yaml
sed -i "/^\([[:space:]]*value: \).*/s//\1${CENTRAL}/" app/policy/kustomization.yaml

git add app/pipeline/kustomization.yaml app/policy/kustomization.yaml
git commit -m "Update routes"
git push

# Add git-credentials secret
 oc apply -f ./app/pipeline/git-credentials-secret.yaml

# Generate ACS API Token
PASSWORD=$(oc get secret -n stackrox central-htpasswd -o json | jq -r '.data.password' | base64 -d)
TOKEN=$(curl -X POST -u "admin:${PASSWORD}" --data-raw '{"name":"gitops-api-token","roles":["Admin"]}' https://${CENTRAL}/v1/apitokens/generate | jq -r '.token')

# Create gitops-api-token secret
oc create secret generic gitops-api-token --from-literal=token=${TOKEN} -n stackrox

# Apply cluster-admin role to application-controller service account
oc adm policy add-cluster-role-to-user cluster-admin -z openshift-gitops-argocd-application-controller -n openshift-gitops

# Install app-of-apps
oc apply -f acs-config-app-of-apps.yaml