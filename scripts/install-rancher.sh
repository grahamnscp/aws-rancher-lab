#!/bin/bash

source ./params.sh
source ./utils/utils.sh
source ./utils/load-tf-output.sh


function installrancher
{
  NODENUM=$1

  NODENAME=${NODE_NAME[${NODENUM}]}
  NODEN=$(echo $NODENAME | cut -d. -f1)
  NODEIP=${NODE_PUBLIC_IP[${NODENUM}]}
  PRIVATEIP=${NODE_PRIVATE_IP[${NODENUM}]}
  RKENAME=${RKE_NAME[${NODENUM}]}
  RANCHERNAME=${RANCHER_NAME[${NODENUM}]}

  Log "========> Installing rancher on $NODEN (HOST: $NODENAME IP: $NODEIP $PRIVATEIP).."

  Log "\_helm install cert-manager jetstack/cert-manager .."
  helm install --kubeconfig=./local/admin${NODENUM}.conf cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace --set crds.enabled=true
  kubectl --kubeconfig=./local/admin${NODENUM}.conf -n cert-manager rollout status deploy/cert-manager

  Log "\_helm install rancher (version=${RANCHERVERSION}).."

  helm install --kubeconfig=./local/admin${NODENUM}.conf rancher rancher-prime/rancher \
    --namespace cattle-system --create-namespace \
    --version=${RANCHERVERSION} \
    --set hostname=${RANCHERNAME} \
    --set replicas=1 \
    --set bootstrapPassword=${BOOTSTRAPADMINPWD} \
    --set noDefaultAdmin=false \
    --set agentTLSMode=system-store

  # wait until cluster fully up
  Log "\_waiting for rancher deployment rollout status.."
  kubectl --kubeconfig=./local/admin${NODENUM}.conf -n cattle-system rollout status deploy/rancher

  Log "\_sleeping for 1 minute.."
  sleep 60

  # loop on pos status
  Log "\_waiting for pod status on rancher${NODENUM}.."
  READY=false
  while ! $READY
  do
    NRC=`kubectl --kubeconfig=./local/admin${NODENUM}.conf get pods --all-namespaces 2>&1 | egrep -v 'Running|Completed|NAMESPACE' | wc -l`
    if [ $NRC -eq 0 ]; then
      echo -n 0
      echo
      Log " \_rancher${NODENUM} components deployed."
      READY=true
    else
      echo -n ${NRC}.
      sleep 10
    fi
  done

  # loop on certificate check
  Log "\_waiting for $RANCHERNAME Server to be available (typically route53 delay).."
  while true
  do
    curl -kv https://$RANCHERNAME 2>&1 | grep -q "dynamiclistener-ca"
    if [ $? != 0 ]
    then
      echo "Waiting for $RANCHERNAME to be online.."
      sleep 5
      continue
    fi
    break
  done
  echo "$RANCHERNAME instance is online";

  Log "Done."
}


function configrancher
{
  NODENUM=$1

  NODENAME=${NODE_NAME[${NODENUM}]}
  NODEN=$(echo $NODENAME | cut -d. -f1)
  NODEIP=${NODE_PUBLIC_IP[${NODENUM}]}
  PRIVATEIP=${NODE_PRIVATE_IP[${NODENUM}]}
  RKENAME=${RKE_NAME[${NODENUM}]}
  RANCHERNAME=${RANCHER_NAME[${NODENUM}]}

  Log "========> Performing initial config on rancher$NODENUM.."

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

  # set rancher server url (needed so rancher cluster import cli creates registration urls)
  Log "\__Setting Rancher URL.."
  curl -sk "https://$RANCHERNAME/v3/settings/server-url" \
    -X PUT \
    -H 'content-type: application/json' \
    -H "Authorization: Bearer $api_token" \
    -d "{\"name\":\"server-url\",\"value\":\"https://$RANCHERNAME\"}"

  Log "\__Overriding min password length.."
  cat <<EOF | kubectl --kubeconfig=local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: management.cattle.io/v3
kind: Setting
metadata:
  name: password-min-length
  namespace: cattle-system
value: "8"
EOF

  # change admin password
  Log "\__Setting Admin Password.."
  curl -sk "https://$RANCHERNAME/v3/users?action=changepassword" \
    -X POST \
    -H 'content-type: application/json' \
    -H "Authorization: Bearer $api_token" \
    -d "{\"currentPassword\":\"$BOOTSTRAPADMINPWD\",\"newPassword\":\"$RANCHERADMINPWD\"}"

  # add rancher extension repositories
  Log "\__Adding Rancher Extensions Repositories.."
  # Rancher Extensions repo
  cat <<EOF | kubectl --kubeconfig=local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: rancher-ui-plugins
  annotations:
    field.cattle.io/description: Rancher UI Plugins
spec:
  gitRepo: https://github.com/rancher/ui-plugin-charts
  gitBranch: main
EOF
  # Partner Extensions repo
  cat <<EOF | kubectl --kubeconfig=local/admin$NODENUM.conf apply -f -  > /dev/null 2>&1
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: partner-extensions
  annotations:
    field.cattle.io/description: Partner UI Extensions
spec:
  gitRepo: https://github.com/rancher/partner-extensions
  gitBranch: main
EOF

  Log "Done."
}

################################################################################
# Main

LogStarted "Installing rancher on nodes.."

Log "\_Adding helm repos locally.."
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-prime https://charts.rancher.com/server-charts/prime
helm repo update

echo
for ((i=1; i<=$NUM_NODES; i++))
do
  installrancher $i
  LogElapsedDuration

  configrancher $i
  LogElapsedDuration
  echo
done

################################################################################

LogCompleted "Done."

# -------------------------------------------------------------------------------------

exit 0
