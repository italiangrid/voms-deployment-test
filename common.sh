#!/bin/bash
 
trap "exit 1" TERM
export TOP_PID=$$

platform=$PLATFORM
test_ca_repo=$DEFAULT_TEST_CA_REPO
emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO

voms_mp=$VOMS_METAPACKAGE
oracle_password=$ORACLE_PASSWORD

test_ca_repo_filename="/etc/yum.repos.d/test_ca.repo"
emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
voms_repo_filename="/etc/yum.repos.d/test_voms.repo"

hostname=$(hostname -f)
vo=vomsci
mail_from=andrea.ceccanti@cnaf.infn.it
populate_vo_script_url="https://raw.github.com/valerioventuri/voms-deployment-test/master/populate-vo.sh"

setup_mysql_db(){
    # Start MySQLD
    execute "service mysqld start"
    execute "sleep 5"
    # Configure root admin account
    execute "mysqladmin -u root password pwd"
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
    execute "mkdir -p /usr/lib64/oracle/11.2.0.3.0/client/lib64/log/diag/clients"
    execute "chmod 777 /usr/lib64/oracle/11.2.0.3.0/client/lib64/log/diag/clients"
}

configure_container() {
    execute "sed -i -e \"s#localhost#$hostname#g\" /etc/voms-admin/voms-admin-server.properties"
}

configure_bdii(){
	echo "Reconfiguring BDII..."
	cat > /etc/sysconfig/bdii << EOF
#SLAPD_CONF=/etc/bdii/bdii-slapd.conf
SLAPD=/usr/sbin/slapd2.4
#BDII_RAM_DISK=no
EOF
	execute "cat /etc/sysconfig/bdii"
}

configure_vo_mysql(){
    # Configure voms

    voms_configure_cmd="voms-configure install --vo $vo \
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
    execute "echo >> /etc/sysconfig/voms; echo 'TNS_ADMIN=/etc/voms' >> /etc/sysconfig/voms" 
}

execute_no_check(){

  echo "[root@`hostname` ~]# $1"
  eval "$1"

}

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1"

  exit_status=$?

  if [ $exit_status -ne 0 ]; then
	echo "Deployment failed"; 
	kill -s TERM $TOP_PID
  fi

}

print_repo_information() {
    echo "EMI repo URL: $emi_repo"
    if [ ! -z "$voms_repo" ]; then
        echo "VOMS repo URL: $voms_repo"
    fi
}

install_emi_repo() {
    execute "wget -q $emi_repo -O $emi_repo_filename"
}

install_test_ca_repo() {
    execute "wget -q $test_ca_repo -O $test_ca_repo_filename"
}

install_voms_repo() {
    if [ ! -z "$voms_repo" ]; then
        execute "wget -q $voms_repo -O $voms_repo_filename"
        execute "echo >> $voms_repo_filename; echo 'priority=1' >> $voms_repo_filename"
    fi
}

run_fetch_crl() {
    # Run fetch-crl (which can fail due to non-fetchable CRLs)
    execute_no_check "fetch-crl -o /etc/grid-security/certificates -l /etc/grid-security/certificates"
}
 
populate_vo() {
    # populate vo
    execute "wget --no-check-certificate $populate_vo_script_url"
    execute "sh populate-vo.sh $vo"
}
 

setup_client_certificate() {
    # Setup certificate for voms-proxy-init test
    execute "mkdir -p .globus"
    execute "cp /usr/share/igi-test-ca/test0.cert.pem .globus/usercert.pem"
    execute "cp /usr/share/igi-test-ca/test0.key.pem .globus/userkey.pem" 
    execute "chmod 600 .globus/usercert.pem"
    execute "chmod 400 .globus/userkey.pem"
}

setup_voms_clients_configuration() {
    # Setup vomsdir & vomses
    # Configure lsc and vomses
    execute "mkdir /etc/vomses"
    execute "cp /etc/voms-admin/$vo/vomses /etc/vomses/$vo"
    execute "mkdir /etc/grid-security/vomsdir/$vo"
    execute "cp /etc/voms-admin/$vo/lsc /etc/grid-security/vomsdir/$vo/$hostname.lsc"
}
