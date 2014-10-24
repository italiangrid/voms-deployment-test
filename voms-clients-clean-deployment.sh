#!/bin/bash
set -e
source common.sh

configure_vomsdir(){
  execute "mkdir -p /etc/grid-security/vomsdir"
  execute "cp /etc/grid-security/hostcert.pem /etc/grid-security/vomsdir"
}

echo "voms-clients3 clean deployment test"
print_repo_information
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
execute "yum -y install voms-clients3 voms-clients"

# Setup certificate for voms-proxy-init test
execute "mkdir -p .globus"
execute "cp /usr/share/igi-test-ca/test0.cert.pem .globus/usercert.pem"
execute "cp /usr/share/igi-test-ca/test0.key.pem .globus/userkey.pem"
execute "chmod 600 .globus/usercert.pem"
execute "chmod 400 .globus/userkey.pem"

configure_vomsdir

# test basic voms-proxy-init command
execute "echo 'pass' | voms-proxy-init --pwstdin --cert .globus/usercert.pem --key .globus/userkey.pem"
execute "echo 'pass' | voms-proxy-init2 --pwstdin --cert .globus/usercert.pem --key .globus/userkey.pem"

echo "VOMS clients succesfully deployed"
