#!/bin/bash
source common.sh

echo "voms-api-java clean deployment test"

print_repo_information
install_test_ca_repo
install_emi_repo
install_voms_repo

# Clean yum database
execute "yum clean all"

# install emi-release package
execute 'yum -y install emi-release'

# install voms-api-java
execute "yum -y install voms-api-java voms-api-java3"

echo "VOMS API Java succesfully deployed"
