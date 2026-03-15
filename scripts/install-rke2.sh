#!/bin/bash

source ./params.sh
source ./utils/utils.sh
source ./utils/load-tf-output.sh


function installrke
{
  NODENUM=$1

  NODENAME=${NODE_NAME[${NODENUM}]}
  NODEN=$(echo $NODENAME | cut -d. -f1)
  NODEIP=${NODE_PUBLIC_IP[${NODENUM}]}
  PRIVATEIP=${NODE_PRIVATE_IP[${NODENUM}]}
  RKENAME=${RKE_NAME[${NODENUM}]}
  RANCHERNAME=${RANCHER_NAME[${NODENUM}]}

  Log "========> Installing RKE2 $NODEN (HOST: $NODENAME IP: $NODEIP $PRIVATEIP).."

  Log "\_Creating cluster config.yaml.."
  cat << EOF >./local/rke2-config.yaml
token: $RKE2_TOKEN
node-name: $NODEN
tls-san:
- $NODENAME
- $NODEIP
- $RKENAME
- $RANCHERNAME
EOF
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo mkdir -p /etc/rancher/rke2"
  scp $SSH_OPTS ./local/rke2-config.yaml ${SSH_USERNAME}@${NODEIP}:~/config.yaml
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo cp config.yaml /etc/rancher/rke2/"

  Log "\_Installing RKE2.."
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo bash -c 'curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} sh - 2>&1 > /root/rke2-install.log 2>&1'"
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo systemctl enable rke2-server.service"
  Log "\_Starting rke2-server.service.."
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo systemctl start rke2-server.service"

  Log "\_Waiting for kubeconfig file to be created.."
  WAIT=30
  UP=false
  while ! $UP
  do
    ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo test -e /etc/rancher/rke2/rke2.yaml && exit 10 </dev/null"
    if [ $? -eq 10 ]; then
      Log " \_Cluster is now configured."
      UP=true
    else
      sleep $WAIT
    fi
  done

  Log "\_Downloading kube admin.conf locally.."
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo cp /etc/rancher/rke2/rke2.yaml ~/admin.conf"
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo chown ${SSH_USERNAME}:users ~/admin.conf"
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo chmod 600 ~/admin.conf"
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "echo export KUBECONFIG=~/admin.conf >> ~/.bashrc"

  # Local admin.conf
  mkdir -p ./local
  if [ -f ./local/admin.conf ] ; then rm ./local/admin.conf ; fi
  scp $SSH_OPTS ${SSH_USERNAME}@${NODEIP}:~/admin.conf ./local/admin${NODENUM}.conf
  sed -i '' "s/127.0.0.1/rke${NODENUM}.$DOMAINNAME/g" ./local/admin${NODENUM}.conf
  chmod 600 ./local/admin${NODENUM}.conf

  Log "\_adding kubectl link to bin.."
  KDIR=`ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "ls /var/lib/rancher/rke2/data/"`
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "cd /usr/local/bin ; sudo ln -s /var/lib/rancher/rke2/data/$KDIR/bin/kubectl kubectl"
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo bash -c 'echo export KUBECONFIG=/etc/rancher/rke2/rke2.yaml >> /root/.bashrc'"
  ssh $SSH_OPTS ${SSH_USERNAME}@${NODEIP} "sudo bash -c 'echo alias k=kubectl >> /root/.bashrc'"

}

################################################################################
# Main

LogStarted "Installing RKE2 on nodes.."

echo
for ((i=1; i<=$NUM_NODES; i++))
do
  installrke $i
  LogElapsedDuration
  echo
done

################################################################################

LogCompleted "Done."

# -------------------------------------------------------------------------------------

exit 0
