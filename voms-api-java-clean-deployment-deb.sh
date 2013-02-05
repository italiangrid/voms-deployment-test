#!/bin/bash

set -e

emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO

hostname=$(hostname -f)

[ -z "$emi_repo" ]  && ( echo "Please set the DEFAULT_EMI_REPO env variable!"; exit 1 )

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1" || ( echo "Deployment failed"; exit 1 )
}

echo "voms-api-java clean deployment test"
echo "EMI repo URL: $emi_repo"
if [ ! -z "$voms_repo" ]; then
    echo "VOMS repo URL: $voms_repo"
fi

# Install emi repo, with priority over debian repos
execute "wget $emi_repo -O emi-repo && cat emi-repo >> /etc/apt/sources.list"
execute "cat << EOF > /etc/apt/preferences
Package: *
Pin: origin "emisoft.web.cern.ch"
Pin-Priority: 600
EOF"

# install the voms repo, with priority over debian and emi
if [ ! -z "$voms_repo" ]; then
    execute "wget $voms_repo -O voms-repo && cat voms-repo >> /etc/apt/source.list"
    execute  "cat << EOF >> /etc/apt/preferences

Package: *
Pin: origin "radiohead.cnaf.infn.it"
Pin-Priority: 700
EOF"
fi

# update apt
execute "apt-get update" 

# install voms-clients
execute 'apt-get install --allow-unauthenticated -y libvoms3-java'
 

echo "VOMS API Java succesfully deployed"
