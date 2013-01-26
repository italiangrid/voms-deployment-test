#!/bin/bash
 
# This script execute a clean deployment test of the emi-voms-mysql package.
#
set -e

emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO

emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
voms_repo_filename="/etc/yum.repos.d/test_voms.repo"
hostname=$(hostname -f)

vo=emi3
mail_from=andrea.ceccanti@cnaf.infn.it

[ -z "$emi_repo" ]  && ( echo "Please set the DEFAULT_EMI_REPO env variable!"; exit 1 )

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1" || ( echo "Deployment failed"; exit 1 )
}

echo "emi-voms-mysql clean deployment test"
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
 
# install emi-voms-mysql
execute 'yum -y install emi-voms-mysql'
 
# Start MySQLD
execute "service mysqld start"
execute "sleep 5"
 
# Configure root admin account
execute "mysqladmin -u root password pwd"
execute "mysqladmin -u root -h $hostname password pwd"


# Configure voms
voms_configure_cmd="voms-configure install --vo $vo \
    --admin-port 16000  \
    --core-port 15000 \
    --hostname $hostname \
    --createdb --deploy-database  \
    --dbusername ${vo}_vo --dbpassword pwd \
    --mail-from $mail_from \
    --smtp-host postino.cnaf.infn.it \
    --dbapwd pwd" 
 
execute "$voms_configure_cmd"

# Configure info providers
execute 'voms-config-info-providers -s local -e'
 
# start bdii
execute 'service bdii start'
 
# start voms
execute 'service voms start'
execute 'service voms-admin start'
 
# wait a while
execute 'sleep 30'
 
# check voms-admin can list groups
execute "voms-admin --vo $vo list-groups"
 
# create test user
execute "voms-admin --vo $vo create-user /usr/share/igi-test-ca/test0.cert.pem"

# Install voms clients
execute "yum -y install voms-clients3"

# Setup certificate for voms-proxy-init test
execute "mkdir -p .globus"
execute "cp /usr/share/igi-test-ca/test0.cert.pem .globus/usercert.pem"
execute "cp /usr/share/igi-test-ca/test0.key.pem .globus/userkey.pem" 
execute "chmod 600 .globus/usercert.pem"
execute "chmod 400 .globus/userkey.pem"

# Setup vomsdir & vomses
# Configure lsc and vomses
execute "mkdir /etc/vomses"
execute "cp /etc/voms-admin/$vo/vomses /etc/vomses/$vo"
execute "mkdir /etc/grid-security/vomsdir/$vo"
execute "cp /etc/voms-admin/$vo/lsc /etc/grid-security/vomsdir/$vo/$hostname.lsc"

# VOMS proxy init test
execute "echo 'pass' | voms-proxy-init -voms $vo --pwstdin --debug"

echo "VOMS succesfully deployed!"
