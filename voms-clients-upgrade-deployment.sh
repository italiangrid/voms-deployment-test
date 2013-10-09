#!/bin/bash
 
set -e
source common.sh

clients_package=voms-clients3

[ $# -eq 1 ] && clients_package=$1
 
configure_vomsdir(){
  execute "mkdir -p /etc/grid-security/vomsdir"
  execute "cp /etc/grid-security/hostcert.pem /etc/grid-security/vomsdir"
}


## Deployment starts HERE

install_test_ca_repo

execute "mkdir emi-release-package"
execute "wget -P emi-release-package $emi_release_package"
execute "yum -y --nogpgcheck localinstall emi-release-package/*.rpm"
execute "yum clean all"
execute "yum -y install voms-clients"

install_cas

setup_client_certificate

execute "echo pass | voms-proxy-init --pwstdin --cert .globus/usercert.pem --key .globus/userkey.pem"

# Remove emi-release package
execute "yum -y remove emi-release"

install_emi_repo
install_voms_repo

# clean yum
execute "yum clean all"

execute "yum -y install emi-release"

if [ "$clients_package" = "voms-clients" ]; then
  execute "yum -y update";
else
  execute "yum -y remove voms-clients"
  execute "yum -y install voms-clients3"
  configure_vomsdir
fi

execute "echo pass | voms-proxy-init --pwstdin --cert .globus/usercert.pem --key .globus/userkey.pem"

echo "VOMS clients succesfully upgraded!"
