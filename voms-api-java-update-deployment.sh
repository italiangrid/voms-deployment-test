#!/bin/bash
source common.sh

install_voms_repo

# clean yum
execute "yum clean all"
execute "yum -y update voms-api-java3 voms-api-java"

echo "VOMS API Java succesfully updated!"
