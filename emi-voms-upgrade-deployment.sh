#!/bin/bash
 
source common.sh

create_yaim_configuration_oracle(){
    cat > site-info.def << EOF
VOMS_DB_TYPE="oracle"
SITE_NAME="voms-certification.cnaf.infn.it"
VOS="$vo"
VOMS_HOST=$hostname
ORACLE_CLIENT="/usr/lib/oracle/10.2.0.4/client64"
ORACLE_CONNECTION_STRING="(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST = voms-db-02.cr.cnaf.infn.it)(PORT = 1521)))(CONNECT_DATA=(SERVICE_NAME = vomsdb2.cr.cnaf.infn.it)))"

VO_${yaim_vo}_VOMS_PORT=15000
VO_${yaim_vo}_VOMS_DB_USER=admin_25
VO_${yaim_vo}_VOMS_DB_PASS=pwd

VOMS_ADMIN_SMTP_HOST=postino.cnaf.infn.it
VOMS_ADMIN_MAIL=andrea.ceccanti@cnaf.infn.it
EOF
    execute "cp site-info.def siteinfo"
}

create_yaim_configuration_mysql(){
    cat > site-info.def << EOF
MYSQL_PASSWORD="pwd"
SITE_NAME="voms-certification.cnaf.infn.it"
VOS="$vo"
VOMS_HOST=$hostname
VOMS_DB_HOST='localhost'
VO_${yaim_vo}_VOMS_PORT=15000
VO_${yaim_vo}_VOMS_DB_USER=${vo}_vo
VO_${yaim_vo}_VOMS_DB_PASS=pwd
VO_${yaim_vo}_VOMS_DB_NAME=voms_${vo}
VOMS_ADMIN_SMTP_HOST=postino.cnaf.infn.it
VOMS_ADMIN_MAIL=andrea.ceccanti@cnaf.infn.it
EOF
    execute "cp site-info.def siteinfo"
}

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

## Deployment scripts starts here

install_test_ca_repo

execute "mkdir emi-release-package"
execute "wget -P emi-release-package $emi_release_package"
execute "yum -y localinstall --nogpgcheck emi-release-package/*.rpm"
execute "yum clean all"
execute "yum -y install $voms_mp"
execute "yum -y install xml-commons-apis"

install_cas

execute "mkdir siteinfo"

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    install_oracle_repo
    # Install oracle instantclients
    execute "yum -y install oracle-instantclient-basic"
    execute "yum -y install $STDCPP_COMPAT_PACKAGE"
    create_yaim_configuration_oracle
fi

if [ "$voms_mp" = "emi-voms-mysql" ]; then
    setup_mysql_db
    create_yaim_configuration_mysql
fi

execute '/opt/glite/yaim/bin/yaim -c -s siteinfo/site-info.def -n VOMS'

# Ensure empty oracle db is in place
if [ "$voms_mp" = "emi-voms-oracle" ]; then
	execute "source /etc/profile.d/grid-env.sh"
	execute "voms-db-deploy.py undeploy --vo $vo"
	execute "voms-db-deploy.py deploy --vo $vo"
	execute "voms-db-deploy.py add-admin --vo $vo --cert /etc/grid-security/hostcert.pem"
fi

# wait a while
execute 'sleep 60'
 
# check voms-admin can list groups
execute "voms-admin --vo $vo list-groups"
 
# populate vo
execute "wget --no-check-certificate $populate_vo_script_url"
execute "sh populate-vo.sh $vo"

# Stop the services
execute "service voms stop"
execute "service voms-admin stop"
execute "service $tomcat stop"

# Remove emi-release package
execute "yum -y remove emi-release"

# Download EMI 3 repos & VOMS repos
install_emi_repo
install_voms_repo

# Remove 10.2 Oracle repo in favour of 11.2 that comes with EMI3
# testing repo
if [ "$voms_mp" = "emi-voms-oracle" ]; then
    execute "rm -f /etc/yum.repos.d/oracle.repo"
fi

# clean yum
execute "yum clean all"

execute "yum -y install emi-release"
execute "yum -y update"
execute "yum -y remove $tomcat"

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    reconfigure_oracle_vo
else
    reconfigure_mysql_vo
fi

configure_container

execute "sh reconfigure-voms.sh"
execute "service voms-admin start"
execute "sleep 30"
execute "voms-admin --vo vomsci list-users" 

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

# Configure info providers
execute 'voms-config-info-providers -s local -e'

# bdii needs ldap2.4 on SL5
if [ "$platform" = "SL5" ]; then
	configure_bdii
fi

# start bdii
execute 'service bdii start'

# Install voms clients
execute "yum -y install voms-clients3"

setup_voms_clients_configuration
setup_client_certificate

# VOMS proxy init test
execute "echo 'pass' | voms-proxy-init -voms $vo --pwstdin --debug"

echo "VOMS succesfully upgraded!"
