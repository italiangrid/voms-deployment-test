#!/bin/bash
 
# This script execute an upgrade deployment of the emi-voms, assuming
# a previous version is alrady running. It update either to the version in EMI-3
# or the development version if the DEFAULT_VOMS_REPO is passed.
#
set -e

emi_release_package=$DEFAULT_EMI2_RELEASE_PACKAGE

emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO
voms_mp=$VOMS_METAPACKAGE
oracle_password=$ORACLE_PASSWORD
oracle_dist=$ORACLE_DIST

emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
voms_repo_filename="/etc/yum.repos.d/test_voms.repo"

populate_vo_script_url="https://raw.github.com/valerioventuri/voms-deployment-test/master/populate-vo.sh"

hostname=$(hostname -f)
vo=vomsci
yaim_vo=$(echo $vo | tr '.' '_' | tr '-' '_' | tr '[a-z]' '[A-Z]') 
mail_from=andrea.ceccanti@cnaf.infn.it
tomcat=$TOMCAT_PACKAGE
platform=$PLATFORM

[ -z "$emi_release_package" ] && ( echo "Please set the DEFAULT_EMI2_RELEASE_PACKAGE env variable!"; exit 1 )
[ -z "$emi_repo" ]  && ( echo "Please set the DEFAULT_EMI_REPO env variable!"; exit 1 )
[ -z "$tomcat" ] && ( echo "Please set the TOMCAT_PACKAGE env variable!"; exit 1)

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    [ -z "$oracle_password" ] && ( echo "Please set the ORACLE_PASSWORD env variable!"; exit 1)
    [ -z "$oracle_dist" ] && ( echo "Please set the ORACLE_DIST env variable!"; exit 1)
fi

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1" || ( echo "Deployment failed"; exit 1 )
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

# stop the services
execute "service voms stop"
execute "service voms-admin stop"

if [ ! -z "$voms_repo" ]; then
    execute "wget -q $voms_repo -O $voms_repo_filename"
    execute "echo >> $voms_repo_filename; echo 'priority=1' >> $voms_repo_filename"
fi

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

# setup certificate for voms-proxy-init test
execute "mkdir -p .globus"
execute "cp /usr/share/igi-test-ca/test0.cert.pem .globus/usercert.pem"
execute "cp /usr/share/igi-test-ca/test0.key.pem .globus/userkey.pem"
execute "chmod 600 .globus/usercert.pem"
execute "chmod 400 .globus/userkey.pem"

# setup vomsdir & vomses
# configure lsc and vomses
# configure lsc and vomses
if [ ! -d "/etc/vomses" ]; then
        execute "mkdir /etc/vomses"
fi

execute "cp /etc/voms-admin/$vo/vomses /etc/vomses/$vo"

if [ ! -d "/etc/grid-security/vomsdir/$vo" ]; then
        execute "mkdir /etc/grid-security/vomsdir/$vo"
fi

execute "cp /etc/voms-admin/$vo/lsc /etc/grid-security/vomsdir/$vo/$hostname.lsc"

# VOMS proxy init test
execute "echo 'pass' | voms-proxy-init -voms $vo --pwstdin --debug"

echo "VOMS succesfully upgraded!"
