#!/bin/bash
 

# This script execute a clean deployment of the emi-voms-mysql package.
#
# It simply installs the EMI-3 version.
#


execute_cmd() {
  echo [root@`hostname` ~]# $1
  eval "$1" || echo "Deployment failed"
}
 
# install the emi repo
execute_cmd 'wget http://eticssoft.web.cern.ch/eticssoft/mock/emi-3-rc-sl5.repo -O /etc/yum.repos.d/emi-3-rc-sl5.repo'
 
# install emi-release
execute_cmd 'yum install -y emi-release'
 
# install the repo where to get emi-voms-mysql
execute_cmd 'wget http://etics-repository.cern.ch/repository/pm/volatile/repomd/id/e0e65f4c-8a74-4763-98b2-20d4cf317714/sl5_x86_64_gcc412EPEL/etics-volatile-build-by-id-protect.repo -O /etc/yum.repos.d/etics-volatile-build-by-id-protect.repo'
execute_cmd 'echo priority=1 >> /etc/yum.repos.d/etics-volatile-build-by-id-protect.repo'
 
# clean
execute_cmd 'yum clean all'
 
# install emi-voms-mysql
execute_cmd 'yum install -y --nogpgcheck emi-voms-mysql'
 
# start mysql
execute_cmd '/etc/init.d/mysqld start'
execute_cmd '/usr/bin/mysqladmin -u root password pwd'
 
# configure voms
execute_cmd '/usr/sbin/voms-configure install --dbtype mysql --vo testvo --createdb --deploy-database --dbauser root --dbapwd pwd --dbusername testvo_dbusr --dbpassword testvo_dbpwd --core-port 15001 --admin-port 15002 --smtp-host mail.cnaf.infn.it --mail-from valerio.venturi@cnaf.infn.it'
 
# prepare the info provider
#execute_cmd '/usr/sbin/voms-config-info-providers -s local -e'
 
# start bdii
#execute_cmd '/sbin/service bdii start'
 
# start voms
execute_cmd '/etc/init.d/voms start testvo'
execute_cmd '/etc/init.d/voms-admin start testvo'
 
# wait a while
execute_cmd 'sleep 30'
 
# check voms-admin can list groups
execute_cmd 'voms-admin --vo testvo list-users'
 
# check a user can be added to the vo
execute_cmd 'cp /usr/share/igi-test-ca/test0.cert.pem .'
execute_cmd 'chmod 400 test0.cert.pem'
execute_cmd 'voms-admin --vo testvo create-user test0.cert.pem'
 
# install voms clients
execute_cmd 'yum install -y voms-clients'
 
# prepare vomsdir and vomses
execute_cmd 'mkdir .voms'
execute_cmd 'cp /etc/voms-admin/testvo/vomses .voms'
 
# check voms-proxy-init
execute_cmd 'cp /usr/share/igi-test-ca/test0.key.pem .'
execute_cmd 'chmod 400 test0.key.pem'
execute_cmd 'echo pass | voms-proxy-init --cert test0.cert.pem --key test0.key.pem --voms testvo'
