#!/bin/bash
 
set -e
emi_release_package=$DEFAULT_EMI2_RELEASE_PACKAGE

emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO

emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
voms_repo_filename="/etc/yum.repos.d/test_voms.repo"

hostname=$(hostname -f)

[ -z "$emi_release_package" ] && ( echo "Please set the DEFAULT_EMI2_RELEASE_PACKAGE env variable!"; exit 1 )
[ -z "$emi_repo" ]  && ( echo "Please set the DEFAULT_EMI_REPO env variable!"; exit 1 )

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1" || ( echo "Deployment failed"; exit 1 )
}
 
execute "mkdir emi-release-package"
execute "wget -P emi-release-package $emi_release_package"
execute "yum -y localinstall emi-release-package/*.rpm"
execute "yum clean all"
execute "yum -y install voms-api-java"

# Remove emi-release package
execute "yum -y remove emi-release"

# Download EMI 3 repos & VOMS repos
execute "wget -q $emi_repo -O $emi_repo_filename"

if [ ! -z "$voms_repo" ]; then
    execute "wget -q $voms_repo -O $voms_repo_filename"
    execute "echo >> $voms_repo_filename; echo 'priority=1' >> $voms_repo_filename"
fi

# clean yum
execute "yum clean all"

execute "yum -y install emi-release"
execute "yum -y update"

execute "yum -y install voms-api-java3"

echo "VOMS clients succesfully upgraded!"
