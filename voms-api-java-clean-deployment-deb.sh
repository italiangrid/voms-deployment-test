#!/bin/bash
source common.sh

echo "voms-api-java clean deployment test"
print_repo_information

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
execute 'apt-get install --allow-unauthenticated -y libvoms3-java'

echo "VOMS API Java succesfully deployed"
