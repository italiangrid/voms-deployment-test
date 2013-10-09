#!/bin/bash

set -e
source common.sh

echo "VOMS clients update deployment test"

install_voms_repo

# Clean yum database
execute "yum clean all"

# install voms-clients
execute "yum -y update"

# test basic voms-proxy-init command
execute "echo 'pass' | voms-proxy-init --pwstdin --cert .globus/usercert.pem --key .globus/userkey.pem"

echo "VOMS clients succesfully deployed"
