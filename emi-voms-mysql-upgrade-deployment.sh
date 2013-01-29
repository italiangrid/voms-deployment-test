#!/bin/bash
 
# This script execute an upgrade deployment of the emi-voms-mysql package.
#
#
set -e

emi_release_package=$DEFAULT_EMI2_RELEASE_PACKAGE

emi_repo=$DEFAULT_EMI_REPO
voms_repo=$DEFAULT_VOMS_REPO

emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
voms_repo_filename="/etc/yum.repos.d/test_voms.repo"

populate_vo_script_url="https://raw.github.com/valerioventuri/voms-deployment-test/master/populate-vo.sh"

hostname=$(hostname -f)
vo=emi3
yaim_vo=$(echo $vo | tr '.' '_' | tr '-' '_' | tr '[a-z]' '[A-Z]') 
mail_from=andrea.ceccanti@cnaf.infn.it
tomcat=tomcat6

[ -z "$emi_release_package" ] && ( echo "Please set the DEFAULT_EMI2_RELEASE_PACKAGE env variable!"; exit 1 )
[ -z "$emi_repo" ]  && ( echo "Please set the DEFAULT_EMI_REPO env variable!"; exit 1 )

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1" || ( echo "Deployment failed"; exit 1 )
}
 
execute "mkdir emi-release-package"
execute "wget -P emi-release-package $emi_release_package"
execute "yum -y localinstall emi-release-package/*.rpm"
execute "yum clean all"
execute "yum -y install emi-voms-mysql"
execute "yum -y install xml-commons-apis"
execute "yum -y install ca_INFN-CA-2006"
execute "service mysqld start"
execute "sleep 5"
execute "/usr/bin/mysqladmin -u root password pwd"
execute "/usr/bin/mysqladmin -u root -h $hostname password pwd"
execute "mkdir siteinfo"

# configure voms using yaim
execute "cat > siteinfo/site-info.def << EOF
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
EOF"

execute '/opt/glite/yaim/bin/yaim -c -s siteinfo/site-info.def -n VOMS'
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

# clean yum
execute "yum clean all"

execute "yum -y install emi-release"
execute "yum -y update"
execute "yum -y remove $tomcat"

execute "cat > reconfigure-voms.sh << EOF
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
EOF"

execute "sh reconfigure-voms.sh"
execute "service voms-admin start"
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
