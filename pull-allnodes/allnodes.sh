#!/bin/sh
set -e

# Print container images on a given node, one per line
function node_images {
    kubectl get node $1 -o jsonpath='{.status.images[*].names[*]}' | \
        tr ' ' '\n'
}

IMAGE="${1}"
TAG="${2}"
IMAGESHORTNAME=$(basename ${IMAGE} | tr '.' '-')
JOBNAME="pull-${IMAGESHORTNAME}-${TAG}-$(date +'%s')"

NODELIST=$(kubectl get node | awk '{ if ($2 == "Ready") print $1; }')
NODECOUNT=$(echo $NODELIST | wc -w)

echo Pulling "${IMAGE}:${TAG}" on ${NODECOUNT} nodes

cat pulljob.yaml \
    | sed "s/{NODECOUNT}/${NODECOUNT}/" \
    | sed "s/{JOBNAME}/${JOBNAME}/" \
    | sed "s_{IMAGE}_${IMAGE}_" \
    | sed "s_{TAG}_${TAG}_" \
    | kubectl apply -f -

for node in ${NODELIST} ; do
    while true; do
        sleep 1
        if [ -n "$(node_images ${node} | grep "${IMAGE}:${TAG}")" ]; then
            echo $node has ${IMAGE}:${TAG}
            break
        else
            echo waiting for ${IMAGE}:${TAG} on $node
        fi
    done
done

echo "All nodes pulled successfully!"
kubectl delete job ${JOBNAME}
