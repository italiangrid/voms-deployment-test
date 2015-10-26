#!/bin/bash
set -ex
trap "exit 1" TERM

WGET_OPTIONS="--no-check-certificate"
VOMS_REPO=${VOMS_REPO:-http://radiohead.cnaf.infn.it:9999/view/REPOS/job/repo_voms_develop_SL6/lastSuccessfulBuild/artifact/voms-develop_sl6.repo}

VO_0_NAME=${VO_0_NAME:-vo.0}
VO_1_NAME=${VO_1_NAME:-vo.1}

VO_0_PORT=${VO_0_PORT:-15000}
VO_1_PORT=${VO_1_PORT:-15001}

MAIL_FROM=${MAIL_FROM:-andrea.ceccanti@cnaf.infn.it}
SMTP_HOST=${SMTP_HOST:-postino.cnaf.infn.it}
LOCAL_HOSTNAME=$(hostname -f)
SLEEP_TIME=${SLEEP_TIME:-5}

EMI_RELEASE_PACKAGE=${EMI_RELEASE_PACKAGE:-emi-release-3.0.0-2.el6.noarch.rpm}
EMI_RELEASE_PACKAGE_URL="http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl6/x86_64/base/${EMI_RELEASE_PACKAGE}"
EMI_GPG_KEY=${EMI_GPG_KEY:-http://emisoft.web.cern.ch/emisoft/dist/EMI/3/RPM-GPG-KEY-emi}

DO_RECONF=${DO_RECONF:-true}
DO_DB_UPGRADE=${DO_DB_UPGRADE:-true}

configure_vos(){
  # Configure VO 0
  voms-configure install --vo ${VO_0_NAME} \
    --core-port ${VO_0_PORT} \
    --hostname ${LOCAL_HOSTNAME} \
    --createdb --deploy-database  \
    --dbusername ${VO_0_NAME} \
    --dbpassword pwd \
    --mail-from ${MAIL_FROM} \
    --smtp-host ${SMTP_HOST} \
    --dbapwd pwd

  # Configure VO 1
  voms-configure install --vo ${VO_1_NAME} \
    --core-port ${VO_1_PORT} \
    --hostname ${LOCAL_HOSTNAME} \
    --createdb --deploy-database  \
    --dbusername ${VO_1_NAME} \
    --dbpassword pwd \
    --mail-from ${MAIL_FROM} \
    --smtp-host ${SMTP_HOST} \
    --dbapwd pwd
}

upgrade_db() {
  voms-configure upgrade --vo ${VO_0_NAME}
  voms-configure upgrade --vo ${VO_1_NAME}
}

# install emi gpg key
rpm --import ${EMI_GPG_KEY}

# install emi-release package
wget $WGET_OPTIONS ${EMI_RELEASE_PACKAGE_URL}
yum localinstall -y ${EMI_RELEASE_PACKAGE}

yum clean all

# install VOMS release in EMI repository
yum -y install emi-voms-mysql

# Startup mysql
service mysqld start
sleep ${SLEEP_TIME}
mysqladmin -uroot password pwd

# Configure VOs
configure_vos

# Configure VOMS container
sed -i -e "s#localhost#${LOCAL_HOSTNAME}#g" /etc/voms-admin/voms-admin-server.properties

# Configure info providers
voms-config-info-providers -s local -e

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# Start BDII
service bdii start

# Run fetch-crl
fetch-crl

# Start VOMS-admin
service voms-admin start

let admin_sleep=SLEEP_TIME*6
sleep ${admin_sleep}

# Check that voms-admin server runs
voms-admin --vo $VO_0_NAME list-groups
voms-admin --vo $VO_1_NAME list-groups

# Populate VOs
sh populate-vo.sh ${VO_0_NAME}
sh populate-vo.sh ${VO_1_NAME}

# Setup LSC file
mkdir -p /etc/grid-security/vomsdir/${VO_0_NAME}
mkdir -p /etc/grid-security/vomsdir/${VO_1_NAME}

cp /etc/voms-admin/${VO_0_NAME}/lsc /etc/grid-security/vomsdir/${VO_0_NAME}/${LOCAL_HOSTNAME}.lsc
cp /etc/voms-admin/${VO_1_NAME}/lsc /etc/grid-security/vomsdir/${VO_1_NAME}/${LOCAL_HOSTNAME}.lsc

service voms start
sleep ${SLEEP_TIME}

echo "Clean install done."

# install voms repo
wget $WGET_OPTIONS $VOMS_REPO -O /etc/yum.repos.d/voms.repo

yum clean all
yum -y update

service voms-admin stop
service voms stop
sleep ${SLEEP_TIME}

if [ ${DO_RECONF} = true ]; then
  configure_vos
fi

if [ ${DO_DB_UPGRADE} = true ]; then
  upgrade_db
fi

# Restart VOMS Admin
service voms-admin start

let admin_sleep=SLEEP_TIME*6
sleep ${admin_sleep}

# Check that voms-admin server runs
voms-admin --vo $VO_0_NAME list-groups
voms-admin --vo $VO_1_NAME list-groups

service voms start
sleep ${SLEEP_TIME}

echo "Done."
