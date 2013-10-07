#!/bin/bash
source common.sh
 
execute "mkdir emi-release-package"
execute "wget -P emi-release-package $emi_release_package"
execute "yum -y --nogpgcheck localinstall emi-release-package/*.rpm"
execute "yum clean all"
execute "yum -y install voms-api-java"

# Remove emi-release package
execute "yum -y remove emi-release"

install_emi_repo
install_voms_repo

# clean yum
execute "yum clean all"

execute "yum -y --nogpgcheck install emi-release"
execute "yum -y update"

execute "yum -y install voms-api-java3"

echo "VOMS API Java succesfully upgraded!"
