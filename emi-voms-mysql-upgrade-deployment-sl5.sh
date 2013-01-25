#!/bin/bash
 

# This script execute an upgrade deployment of the emi-voms-mysql package.
#
# It installs the EMI-3 version over the last update of EMI-2.
#

export PATH="/usr/sbin:$PATH"

execute_cmd() {
  echo [root@`hostname` ~]# $1
  eval "$1" || echo "Deployment failed"
}
 
# install the EMI-2 emi-release package
#execute_cmd 'wget http://emisoft.web.cern.ch/emisoft/dist/EMI/2/sl5/x86_64/base/emi-release-2.0.0-1.sl5.noarch.rpm'
#execute_cmd 'rpm -i emi-release-2.0.0-1.sl5.noarch.rpm'
 
# clean yum
#execute_cmd 'yum clean all'
 
# install emi-voms-mysql
#execute_cmd 'yum install -y --nogpgcheck emi-voms-mysql'

# install xml-commons-apis
#execute_cmd 'yum install -y --nogpgcheck xml-commons-apis'
 
# start mysql and configure root access
#execute_cmd '/etc/init.d/mysqld start'
#execute_cmd '/usr/bin/mysqladmin -u root password pwd'
 
# configure voms using yaim
#execute_cmd "cat > site-info.def << EOF
#MYSQL_PASSWORD="pwd"
#SITE_NAME="voms-certification.cnaf.infn.it"
#VOS="testvo"
#VOMS_HOST=`hostname -f`
#VOMS_DB_HOST='localhost'
#VO_TESTVO_VOMS_PORT=15000
#VO_TESTVO_VOMS_DB_USER=voms
#VO_TESTVO_VOMS_DB_PASS=pwd
#VO_TESTVO_VOMS_DB_NAME=voms_emi2to3
#VOMS_ADMIN_SMTP_HOST=postino.cnaf.infn.it
#VOMS_ADMIN_MAIL=andrea.ceccanti@cnaf.infn.it
#EOF"
#execute_cmd '/opt/glite/yaim/bin/yaim -c -s site-info.def -n VOMS'

# wait a while
#execute_cmd 'sleep 30'
 
# check voms-admin can list groups
#execute_cmd 'voms-admin --vo testvo list-users'
 
# check a user can be added to the vo
#execute_cmd 'cp /usr/share/igi-test-ca/test0.cert.pem .'
#execute_cmd 'chmod 400 test0.cert.pem'
#execute_cmd 'voms-admin --vo testvo create-user test0.cert.pem'
 
# install voms clients
#execute_cmd 'yum install -y voms-clients'
 
# prepare vomsdir and vomses
#execute_cmd 'mkdir .glite'
#execute_cmd 'cp /etc/voms-admin/testvo/vomses .glite'
 
# check voms-proxy-init
#execute_cmd 'cp /usr/share/igi-test-ca/test0.key.pem .'
#execute_cmd 'chmod 400 test0.key.pem'
#execute_cmd 'echo pass | voms-proxy-init --cert test0.cert.pem --key test0.key.pem --voms testvo --pwstdin'

# Stop the services
execute_cmd "service voms stop"
execute_cmd "service voms-admin stop"
execute_cmd "service $tomcat stop"

# Remove emi-release package
execute_cmd "yum -y remove emi-release"

# Download EMI 3 repos & VOMS repos
execute_cmd "wget -P /etc/yum.repos.d http://eticssoft.web.cern.ch/eticssoft/mock/emi-3-rc-sl5.repo"
execute_cmd "wget -P /etc/yum.repos.d http://etics-repository.cern.ch/repository/pm/volatile/repomd/id/e0e65f4c-8a74-4763-98b2-20d4cf317714/sl5_x86_64_gcc412EPEL/etics-volatile-build-by-id-protect.repo"

# clean yum
execute_cmd "yum clean all"

# remove a few packages
execute_cmd "yum -y remove tomcat6 emi-trustmanager emi-trustmanager-tomcat"

# install emi-release
execute_cmd "yum -y install emi-release"

# update
execute_cmd "yum -y install emi-voms-mysql"
execute_cmd "yum -y update"

