#!/bin/bash -xeu

# Create cluster, install deps
k3d cluster create --config k3d.conf
kubectl get pods -Aw &
kubectl create namespace minio && kubectl -n minio apply -f minio
kubectl create namespace postgres && kubectl -n postgres apply -f postgres
kubectl create namespace argo
kubectl apply -n argo -f workflows-additions

# Install Argo w/out archive
cd argo-workflows
helm dependency update
helm template -n argo  argo-workflows -f values.yaml -f values.archives.yaml . > todeploy.yaml
kubectl apply -n argo -f todeploy.yaml
kubectl get workflows -Aw &
kubectl -n argo rollout status deployment/argo-workflows-workflow-controller
kubectl -n argo rollout status deployment/argo-workflows-server
cd ..
kubectl -n argo port-forward svc/argo-workflows-server 2746:2746 &

# Create and wait for workflow to finish
wf_name=$(kubectl -n argo create -f hello-world/hello-world.yaml -o name | awk -F '/' '{ print $2 }')
argo -n argo wait "${wf_name}"

# Delete workflow, check archive
kubectl -n argo get workflow "${wf_name}" -o yaml | tee /dev/stderr > wf-final-archive.yaml
kubectl -n argo delete workflow "${wf_name}"
if ! ARGO_SERVER=localhost:2746 ARGO_TOKEN='BEARER foo' ARGO_INSECURE_SKIP_VERIFY=true argo -n argo archive get "${wf_name}"; then
    echo 'Workflow was not archived!'
fi

# Debugging
if [ -z "${BATCH_MODE:-}" ]; then
    if which xdg-open; then
        xdg-open https://localhost:2746
    elif which open; then
        open https://localhost:2746
    fi
    read -p "Paused, press enter to clean up cluster"
fi

# Cleanup
k3d cluster delete workflow-archiving
