#!/usr/bin/bash

echo "==========> Started userdata script.."

sudo echo "alias l='ls -latFrh'" >> /home/ec2-user/.bashrc
sudo echo "alias vi=vim"         >> /home/ec2-user/.bashrc
sudo echo "set background=dark"  >> /home/ec2-user/.vimrc
sudo echo "syntax on"            >> /home/ec2-user/.vimrc
sudo echo "alias l='ls -latFrh'" >> /root/.bashrc
sudo echo "alias vi=vim"         >> /root/.bashrc
sudo echo "set background=dark"  >> /root/.vimrc
sudo echo "syntax on"            >> /root/.vimrc

# packages
zypper refresh
zypper --non-interactive install -y git bind-utils mlocate lvm2 jq nfs-client cryptsetup open-iscsi
# net-tools-deprecated

# services
systemctl enable iscsid --now

updatedb

echo "==========> Exiting userdata script."
exit 0

