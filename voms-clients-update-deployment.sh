#!/bin/bash

set -e
voms_repo=$DEFAULT_VOMS_REPO

voms_repo_filename="/etc/yum.repos.d/voms_update.repo"
hostname=$(hostname -f)

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1" || ( echo "Deployment failed"; exit 1 )
}

echo "VOMS clients update deployment test"

if [ ! -z "$voms_repo" ]; then
    echo "Update repo URL: $voms_repo"
fi

if [ ! -z "$voms_repo" ]; then
    execute "wget -q $voms_repo -O $voms_repo_filename"
    execute "echo >> $voms_repo_filename; echo 'priority=1' >> $voms_repo_filename"
fi

# Clean yum database
execute "yum clean all"

# install voms-clients
execute "yum -y update"

# test basic voms-proxy-init command
execute "echo 'pass' | voms-proxy-init --pwstdin --cert .globus/usercert.pem --key .globus/userkey.pem"

echo "VOMS clients succesfully deployed"
