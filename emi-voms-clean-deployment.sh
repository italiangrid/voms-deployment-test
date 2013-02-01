#!/bin/bash
 
# This script execute a clean deployment test of the emi-voms-mysql package.
#
set -e

emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO
voms_mp=$VOMS_METAPACKAGE
oracle_password=$ORACLE_PASSWORD

emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
voms_repo_filename="/etc/yum.repos.d/test_voms.repo"
hostname=$(hostname -f)

vo=emi3
mail_from=andrea.ceccanti@cnaf.infn.it

[ -z "$emi_repo" ]  && ( echo "Please set the DEFAULT_EMI_REPO env variable!"; exit 1 )
[ -z "$voms_mp" ] && ( echo "Please set the VOMS_METAPACKAGE env variable!"; exit 1)

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    [ -z "$oracle_password" ] && ( echo "Please set the ORACLE_PASSWORD env variable!"; exit 1)
fi

setup_mysql_db(){

    # Start MySQLD
    execute "service mysqld start"
    execute "sleep 5"
    # Configure root admin account
    execute "mysqladmin -u root password pwd"
    execute "mysqladmin -u root -h $hostname password pwd"
}

setup_oracle_db(){
    # Install oracle instantclients
    execute "yum -y install oracle-instantclient-basic"

    # Configure TNS names ora 
    cat > tnsnames.ora << EOF
voms=(DESCRIPTION =
        (ADDRESS_LIST =
        (ADDRESS = (PROTOCOL = TCP)(HOST = voms-db-02.cr.cnaf.infn.it)(PORT = 1521)))
        (CONNECT_DATA = (SERVICE_NAME = vomsdb2.cr.cnaf.infn.it))
    )
EOF
     
    execute "cp tnsnames.ora /etc/voms"
}

configure_vo_mysql(){
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
}

configure_vo_oracle(){
    # Configure voms

    voms_configure_cmd="voms-configure install --vo $vo \
    --admin-port 16000 \
    --core-port 15000 \
    --hostname $hostname \
    --dbtype oracle \
    --dbname voms \
    --deploy-database \
    --dbusername admin_25 \
    --dbpassword $ORACLE_PASSWORD \
    --mail-from $mail_from \
    --smtp-host postino.cnaf.infn.it"

    execute "$voms_configure_cmd"
}

execute_no_check(){

  echo "[root@`hostname` ~]# $1"
  eval "$1"

}

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
execute "yum -y install $voms_mp"
 

# Setup databases
if [ "$voms_mp"  = "emi-voms-mysql" ]; then
    setup_mysql_db
    configure_vo_mysql
else
    setup_oracle_db
    configure_vo_oracle
fi

# Install INFN CA
execute "yum -y install ca_INFN-CA-2006"

# Configure info providers
execute 'voms-config-info-providers -s local -e'
 
# start bdii
execute 'service bdii start'

# Run fetch-crl (which can fail due to non-fetchable CRLs)
execute_no_check "fetch-crl -o /etc/grid-security/certificates -l /etc/grid-security/certificates"
 
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
