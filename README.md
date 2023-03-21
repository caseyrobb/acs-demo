# RHACS Policy Management with GitOps
This repo contains an example of how to manage Red Hat Advanced Cluster Security for Kubernetes policies using a combination of OpenShift GitOps (ArgoCD) and Pipelines (Tekton).  It works in conjunction with the [acs-policies](https://github.com/caseyrobb/acs-policies) repository to combine the indiviual policies (in JSON) format to a single [ConfigMap](https://github.com/caseyrobb/acs-demo/blob/master/app/policy/policies-payload-cm.yaml).

A Job is then triggered by OpenShift GitOps to then update the policies in RHACS via the API.

## Flowchart
Below is a diagram along with steps detailing the process:

![alt text](https://raw.githubusercontent.com/caseyrobb/acs-demo/master/flowchart.png)

1. User pushes a change to the [acs-policies](https://github.com/caseyrobb/acs-policies) repo
2. A webhook triggers an EventListener and runs the pipeline to build the ConfigMap
3. The ConfigMap is then pushed to the [acs-demo](https://github.com/caseyrobb/acs-demo/blob/master/app/policy/policies-payload-cm.yaml) repo
4. The [acs-config-policy-app](https://github.com/caseyrobb/acs-demo/blob/master/argocd/acs-config-policy-app.yaml) detects the new ConfigMap and syncs the changes
5. The sync kicks off the [policy-config-job](https://github.com/caseyrobb/acs-demo/blob/master/app/policy/policy-config-job.yaml)
6. The Job updates the RHACS policies and proceeds to delete itself upon success using a [post-sync hook](https://github.com/caseyrobb/acs-demo/blob/master/app/policy/policy-config-job.yaml#L6), allowing it to be run again the next time the Application syncs.

## Pipeline
![alt text](https://raw.githubusercontent.com/caseyrobb/acs-demo/master/pipeline.png)

## Pre-Requisites
1. Install OpenShift GitOps
```
$ oc apply -k https://github.com/redhat-cop/gitops-catalog/openshift-gitops-operator/overlays/gitops-1.7
```
2. Install OpenShift Pipelines
```
$ oc apply -k https://github.com/redhat-cop/gitops-catalog/openshift-piplines-operator/overlays/pipelines-1.9
```
3. Install RHACS
```
$ oc apply -k https://github.com/redhat-cop/gitops-catalog/advanced-cluster-security-operator/aggregate/default
```

## Usage
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
2. Add the app-of-apps, which will deploy acs-config-auth-app, acs-config-policy-app and acs-config-pipeline-app
```
$ oc apply -f acs-config-app-of-apps.yaml
```

