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

  Log "\__Authenticating to Rancher Manager API.."

  # login with username / password then obtain an api_token
  token=$(curl -sk "https://$RANCHERNAME/v3-public/localProviders/local?action=login" \
    -X POST \
    -H 'content-type: application/json' \
    -d "{\"username\":\"admin\",\"password\":\"$BOOTSTRAPADMINPWD\"}" | jq -r .token \
  )
  api_token=$(curl -sk "https://$RANCHERNAME/v3/token" \
    -X POST \
    -H 'content-type: application/json' \
    -H "Authorization: Bearer $token" \
    -d '{"type":"token","description":"automation"}' | jq -r .token \
  )
  if [ "$api_token" == "" ]
  then
    LogError "Failed to get API token, exiting.."
    exit 1
  fi

  # suse application collection
  kubectl --kubeconfig=./local/admin$NODENUM.conf create secret docker-registry clusterrepo-auth-appcol --docker-server=dp.apps.rancher.io --docker-username=$APPCOL_USER --docker-password=$APPCOL_TOKEN -n cattle-system
  # clusterrepo
  cat <<EOF | kubectl --kubeconfig=local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: suse-app-collection
  annotations:
    field.cattle.io/description: SUSE Application Collection
spec:
  clientSecret:
    name: clusterrepo-auth-appcol
    namespace: cattle-system
  insecurePlainHttp: false
  url: oci://dp.apps.rancher.io/charts
EOF

  # cattle-ui-plugin-system - suse-ai-lifecycle-manager
  # https://documentation.suse.com/suse-ai/1.0/html/AI-deployment/ai-alternative-deployments.html#ai-lifecycle-manager-clusterrepo-creating

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
