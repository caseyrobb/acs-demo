# RHACS Policy Management with GitOps
This repo contains an example of how to manage Red Hat Advanced Cluster Security for Kubernetes policies using a combination of OpenShift GitOps (ArgoCD) and Pipelines (Tekton).  It works in conjunction with the [acs-policies](https://github.com/caseyrobb/acs-policies) repository to combine the indiviual policies (in JSON) format to a single [ConfigMap](https://github.com/caseyrobb/acs-demo/blob/master/app/policy/policies-payload-cm.yaml).

A Job is then triggered by OpenShift GitOps to then update the policies in RHACS via the API.

## Flowchart
Below is a diagram along with steps outlining the process:

![alt text](https://raw.githubusercontent.com/caseyrobb/acs-demo/master/flowchart.png)

1. A policy change is pushed to the [acs-policies](https://github.com/caseyrobb/acs-policies) repository.
2. A webhook triggers the pipeline which combines all the policies and builds a ConfigMap.
3. The new ConfigMap is pushed to the [acs-demo](https://github.com/caseyrobb/acs-demo/blob/master/app/policy/policies-payload-cm.yaml) repository which is monitored by OpenShift GitOps.
4. The ArgoCD application [acs-config-policy-app](https://github.com/caseyrobb/acs-demo/blob/master/argocd/acs-config-policy-app.yaml) detects the new ConfigMap and syncs the changes.
5. The sync creates the Job [import-policies-job](https://github.com/caseyrobb/acs-demo/blob/master/app/policy/import-policies-job.yaml).
6. The Job updates the RHACS policies via the API and proceeds to delete itself upon success using a [post-sync hook](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/#hook-deletion-policies).  This allows the Job to be run again the next time a new ConfigMap is detected and the Application syncs.

## Pipeline
![alt text](https://raw.githubusercontent.com/caseyrobb/acs-demo/master/pipeline.png)

## Pre-Requisites
1. Install OpenShift GitOps
```
$ oc apply -k https://github.com/redhat-cop/gitops-catalog/openshift-gitops-operator/overlays/latest
```
2. Install OpenShift Pipelines
```
$ oc apply -k https://github.com/redhat-cop/gitops-catalog/openshift-piplines-operator/overlays/latest
```
3. Install RHACS
```
$ oc apply -k https://github.com/redhat-cop/gitops-catalog/advanced-cluster-security-operator/aggregate/default
```

## Usage
The pipeline requires a secret named `git-credentials` which contains an SSH config, private key and known_hosts file allowing authentication to GitHub:

1. Create a git-credentials secret:
```
$ cat <<EOF > config
Host github.com
HostName github.com
IdentityFile ~/.ssh/id_ed25519
User git
EOF

$ cat <<EOF > known_hosts
github.com ssh-ed25519 AAAAC3Nza...
github.com ssh-rsa AAAAB3Nza...
github.com ecdsa-sha2-nistp256 AAAAE2VjZHN...
[ssh.github.com]:443 ssh-ed25519 AAAAC3Nza...
EOF

$ cat <<EOF > id_ed25519
-----BEGIN OPENSSH PRIVATE KEY-----
...
...my private key...
...
-----END OPENSSH PRIVATE KEY-----
EOF

$ oc create secret generic git-credentials \
    -n stackrox \
    --from-file=config \
    --from-file=known_hosts \
    --from-file=id_ed25519 
```
2. Add the app-of-apps, which deploys acs-config-policy-app and acs-config-pipeline-app
```
$ oc apply -f acs-config-app-of-apps.yaml
```

