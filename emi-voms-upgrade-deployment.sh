#!/bin/bash
 
# This script execute an upgrade deployment of the emi-voms-mysql package.
#
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
vo=emi3
yaim_vo=$(echo $vo | tr '.' '_' | tr '-' '_' | tr '[a-z]' '[A-Z]') 
mail_from=andrea.ceccanti@cnaf.infn.it
tomcat=$TOMCAT_PACKAGE

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
 
setup_oracle_db(){
    # Install emi devel oracle repo

    cat > oracle.repo << EOF
[Oracle]
name=Oracle Repository (not for distribution)
baseurl=http://emisoft.web.cern.ch/emisoft/dist/elcaro/oracle-instantclient/10.2.0.4/repo/$oracle_dist
protect=1
enabled=1
priority=2
gpgcheck=0
EOF
    execute "cp oracle.repo /etc/yum.repos.d"

    # Install oracle instantclients
    execute "yum -y install oracle-instantclient-basic"
	execute "yum -y install $STDCPP_COMPAT_PACKAGE"
}

setup_mysql_db(){
    execute "service mysqld start"
    execute "sleep 5"
    execute "/usr/bin/mysqladmin -u root password pwd"
    execute "/usr/bin/mysqladmin -u root -h $hostname password pwd"
}

configure_oracle_vo(){

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

configure_mysql_vo(){

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
--admin-port 16000 \
--hostname $hostname \
--dbusername ${vo}_vo \
--dbpassword pwd \
--dbname voms_${vo} \
--mail-from $mail_from \
--smtp-host postino.cnaf.infn.it
EOF

}

reconfigure_oracle_vo(){
    cat > reconfigure-voms.sh << EOF
#!/bin/bash
hostname=$(hostname -f)
voms-configure install --vo $vo \
--dbtype oracle \
--core-port 15000 \
--admin-port 16000 \
--hostname $hostname \
--dbusername admin_25 \
--dbpassword $oracle_password \
--dbname DB_VOMS \
--mail-from $mail_from \
--smtp-host postino.cnaf.infn.it
EOF
}

execute "mkdir emi-release-package"
execute "wget -P emi-release-package $emi_release_package"
execute "yum -y localinstall emi-release-package/*.rpm"
execute "yum clean all"
execute "yum -y install $voms_mp"
execute "yum -y install xml-commons-apis"
execute "yum -y install ca_INFN-CA-2006"

execute "mkdir siteinfo"

if [ "$voms_mp" = "emi-voms-oracle" ]; then
    setup_oracle_db
    configure_oracle_vo
fi

if [ "$voms_mp" = "emi-voms-mysql" ]; then
    setup_mysql_db
    configure_mysql_vo
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
execute 'sleep 10'
 
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
execute "wget -q $emi_repo -O $emi_repo_filename"

if [ ! -z "$voms_repo" ]; then
    execute "wget -q $voms_repo -O $voms_repo_filename"
    execute "echo >> $voms_repo_filename; echo 'priority=1' >> $voms_repo_filename"
fi

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
# Configure lsc and vomses
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
