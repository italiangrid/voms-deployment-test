#!/bin/bash

# This script execute a clean deployment of the voms-clients3 package.
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
 
# install the repo where to get voms-clients3
execute_cmd 'wget http://radiohead.cnaf.infn.it:9999/view/REPOS/job/repo_voms_SL5/lastSuccessfulBuild/artifact/voms.repo -O /etc/yum.repos.d/voms.repo'
 
# clean
execute_cmd 'yum clean all'
 
# install voms-clients
execute_cmd 'yum install -y --nogpgcheck voms-clients3'
 
# check voms-proxy-init works
execute_cmd 'cp /usr/share/igi-test-ca/test0.cert.pem .'
execute_cmd 'chmod 400 test0.cert.pem'
execute_cmd 'cp /usr/share/igi-test-ca/test0.key.pem .'
execute_cmd 'chmod 400 test0.key.pem'
execute_cmd 'printf pass | voms-proxy-init --cert test0.cert.pem --key test0.key.pem --pwstdin'
