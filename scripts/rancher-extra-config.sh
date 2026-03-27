#!/bin/bash

source ./params.sh
source ./utils/utils.sh
source ./utils/load-tf-output.sh


function configrancher
{
  NODENUM=$1

  NODENAME=${NODE_NAME[${NODENUM}]}
  NODEN=$(echo $NODENAME | cut -d. -f1)
  NODEIP=${NODE_PUBLIC_IP[${NODENUM}]}
  PRIVATEIP=${NODE_PRIVATE_IP[${NODENUM}]}
  RKENAME=${RKE_NAME[${NODENUM}]}
  RANCHERNAME=${RANCHER_NAME[${NODENUM}]}

  Log "========> Performing extra config on rancher$NODENUM.."

  # Add application-collection repo
  Log "Creating application-collection clusterrepo on rancher$NODENUM.."

  # secret
  cat <<EOF | kubectl --kubeconfig=local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: v1
kind: Secret
metadata:
  name: clusterrepo-auth-suseappcol
  namespace: cattle-system
type: kubernetes.io/basic-auth
stringData:
  username: $APPCOL_USER
  password: $APPCOL_TOKEN
EOF

  # clusterrepo
  cat <<EOF | kubectl --kubeconfig=local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: application-collection
  annotations:
    field.cattle.io/description: SUSE Application Collection
spec:
  clientSecret:
    name: clusterrepo-auth-suseappcol
    namespace: cattle-system
  insecurePlainHttp: false
  url: oci://dp.apps.rancher.io/charts
EOF

  # Add suse-ai-registry repo
  Log "Creating suse-ai-registry clusterrepo on rancher$NODENUM.."

  # secret
  cat <<EOF | kubectl --kubeconfig=local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: v1
kind: Secret
metadata:
  name: clusterrepo-auth-suseaireg
  namespace: cattle-system
type: kubernetes.io/basic-auth
stringData:
  username: regcode
  password: $SUSE_AI_SUB
EOF

  # clusterrepo
  cat <<EOF | kubectl --kubeconfig=./local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: suse-ai-registry
  annotations:
    field.cattle.io/description: SUSE AI Registry
spec:
  clientSecret:
    name: clusterrepo-auth-suseaireg
    namespace: cattle-system
  insecurePlainHttp: false
  url: oci://registry.suse.com/ai/charts
EOF

  # cattle-ui-plugin-system - suse-ai-lifecycle-manager operator
  # https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/ai-alternative-deployments.html#ai-lifecycle-manager-clusterrepo-creating

  Log "Creating creating UI Extension Catalog and installing suse-ai-lifecycle-manager on rancher$NODENUM.."

  # install operator
  helm install --kubeconfig=./local/admin$NODENUM.conf suse-ai-operator \
    oci://ghcr.io/suse/chart/suse-ai-operator \
    -n suse-ai-operator-system --create-namespace \
    --version 0.1.0 

  # Install suse-ai-lifecycle-manager extension, created ui extension catalog and repo
  cat <<EOF | kubectl --kubeconfig=./local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: ai-platform.suse.com/v1alpha1
kind: InstallAIExtension
metadata:
  name: suseai
spec:
  helm:
    name: suse-ai-lifecycle-manager
    url: "oci://ghcr.io/suse/chart/suse-ai-lifecycle-manager"
    version: "1.0.0"
  extension:
    name: suse-ai-lifecycle-manager
    version: "1.0.0"
EOF

  Log "Done."
}

################################################################################
# Main

LogStarted "Rancher extra config.."

echo
for ((i=1; i<=$NUM_NODES; i++))
do
  configrancher $i
  LogElapsedDuration
  echo
done

################################################################################

LogCompleted "Done."

# -------------------------------------------------------------------------------------

exit 0
