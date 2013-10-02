#!/bin/bash

source common.sh

reconfigure_mysql_vo(){
    cat > reconfigure-voms.sh << EOF
#!/bin/bash
hostname=$(hostname -f)
voms-configure install --vo $vo \
--core-port 15000 \
--hostname $hostname \
--dbusername ${vo}_vo \
--dbpassword pwd \
--dbname voms_${vo} \
--mail-from $mail_from \
--smtp-host postino.cnaf.infn.it

if [ "$PERFORM_DATABASE_UPGRADE" = "yes" ]; then
	voms-configure upgrade --vo $vo
fi
EOF

}

reconfigure_oracle_vo(){
    cat > reconfigure-voms.sh << EOF
#!/bin/bash
hostname=$(hostname -f)
voms-configure install --vo $vo \
--dbtype oracle \
--core-port 15000 \
--hostname $hostname \
--dbusername admin_25 \
--dbpassword $oracle_password \
--dbname DB_VOMS \
--mail-from $mail_from \
--smtp-host postino.cnaf.infn.it

if [ "$PERFORM_DATABASE_UPGRADE" = "yes" ]; then
	voms-configure upgrade --vo $vo
fi
EOF
}

## Script execution starts here
[ -z "$emi_release_package" ] &&  error_and_exit "Please set the DEFAULT_EMI2_RELEASE_PACKAGE env variable!"
[ -z "$emi_repo" ]  &&  error_and_exit "Please set the DEFAULT_EMI_REPO env variable!"
[ -z "$tomcat" ] && error_and_exit "Please set the TOMCAT_PACKAGE env variable!"

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    [ -z "$oracle_password" ] && error_and_exit "Please set the ORACLE_PASSWORD env variable!"
    [ -z "$oracle_dist" ] && error_and_exit "Please set the ORACLE_DIST env variable!"
fi

# stop the services
execute "service voms stop"
execute "service voms-admin stop"

install_voms_repo

# clean yum
execute "yum clean all"
execute "yum -y update"

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    reconfigure_oracle_vo
else
    reconfigure_mysql_vo
fi

execute "sh reconfigure-voms.sh"
execute "service voms-admin start"

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    cat > sysconfig.voms << EOF
VOMS_USER=voms
TNS_ADMIN=/etc/voms
EOF
    execute "cp sysconfig.voms /etc/sysconfig/voms"
fi

execute "service voms start"
execute "sleep 20"

# start bdii
execute 'service bdii stop'

# bdii needs ldap2.4 on SL5
if [ "$platform" = "SL5" ]; then
	configure_bdii
fi

# start bdii
execute 'service bdii start'

# check voms-admin can list groups and users
execute "voms-admin --vo $vo list-groups"
execute "voms-admin --vo $vo list-users"

# install voms clients
execute "yum -y install voms-clients3"

setup_voms_clients_configuration
setup_client_certificate

# VOMS proxy init test
execute "echo 'pass' | voms-proxy-init -voms $vo --pwstdin --debug"

echo "VOMS succesfully upgraded!"
