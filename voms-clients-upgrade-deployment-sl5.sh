#!/bin/bash
 
# This script execute an upgrade deployment of the voms-clients package.
#
# It installs the EMI-3 version over the EMI-2 latest update.
#

execute_cmd() {
  echo [root@`hostname` ~]# $1
  eval "$1" || echo "Deployment failed"
}
 
# install the EMI-2 emi-release package
execute_cmd 'wget http://emisoft.web.cern.ch/emisoft/dist/EMI/2/sl5/x86_64/base/emi-release-2.0.0-1.sl5.noarch.rpm'
execute_cmd 'rpm -i emi-release-2.0.0-1.sl5.noarch.rpm'
 
# clean yum
execute_cmd 'yum clean all'
 
# install voms-clients
execute_cmd 'yum install -y --nogpgcheck voms-clients'
 
# check voms-proxy-init works
execute_cmd 'cp /usr/share/igi-test-ca/test0.cert.pem .'
execute_cmd 'chmod 400 test0.cert.pem'
execute_cmd 'cp /usr/share/igi-test-ca/test0.key.pem .'
execute_cmd 'chmod 400 test0.key.pem'
execute_cmd 'printf pass | voms-proxy-init --cert test0.cert.pem --key test0.key.pem --pwstdin'

# install the repo where to get the new voms-clients
execute_cmd 'wget http://etics-repository.cern.ch/repository/pm/volatile/repomd/id/e0e65f4c-8a74-4763-98b2-20d4cf317714/sl5_x86_64_gcc412EPEL/etics-volatile-build-by-id-protect.repo -O /etc/yum.repos.d/etics-volatile-build-by-id-protect.repo'
execute_cmd 'echo priority=1 >> /etc/yum.repos.d/etics-volatile-build-by-id-protect.repo'

# clean yum
execute_cmd 'yum clean all'

# upgrade voms-clients
execute_cmd 'yum update -y voms-clients'

# check voms-proxy-init again
execute_cmd 'printf pass | voms-proxy-init --cert test0.cert.pem --key test0.key.pem --pwstdin'
