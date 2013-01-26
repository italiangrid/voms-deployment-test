#!/bin/bash

set -e

emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO

emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
voms_repo_filename="/etc/yum.repos.d/test_voms.repo"
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

# Install emi repo
execute "wget -q $emi_repo -O $emi_repo_filename"

if [ ! -z "$voms_repo" ]; then
    execute "wget -q $voms_repo -O $voms_repo_filename"
    execute "echo >> $voms_repo_filename; echo 'priority=1' >> $voms_repo_filename"
fi

# Clean yum database
execute "yum clean all"

# install emi-release package
execute 'yum -y install emi-release'

# install voms-clients
execute "yum -y install voms-api-java voms-api-java3"

echo "VOMS API Java succesfully deployed"
