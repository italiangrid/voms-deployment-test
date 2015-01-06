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

PERFORM_DATABASE_UPGRADE=${PERFORM_DATABASE_UPGRADE:-no}

# install emi gpg key
rpm --import ${EMI_GPG_KEY}

# install emi-release package
wget $WGET_OPTIONS ${EMI_RELEASE_PACKAGE_URL}
yum localinstall -y ${EMI_RELEASE_PACKAGE}

yum clean all
yum -y install emi-voms-mysql

# Startup mysql
service mysqld start
sleep ${SLEEP_TIME}
mysqladmin -uroot password pwd

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

# Configure VOMS container
sed -i -e "s#localhost#${LOCAL_HOSTNAME}#g" /etc/voms-admin/voms-admin-server.properties

# Configure info providers
voms-config-info-providers -s local -e

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

# install voms repo
wget $WGET_OPTIONS $VOMS_REPO -O /etc/yum.repos.d/voms.repo

# Packeges update
yum clean all -y
yum update -y

if [ "$PERFORM_DATABASE_UPGRADE" = yes ]; then
	service voms stop
	service voms-admin stop
fi

# Reconfigure VO 0
voms-configure install --vo ${VO_0_NAME} \
  --core-port ${VO_0_PORT} \
  --hostname ${LOCAL_HOSTNAME} \
  --dbusername ${VO_0_NAME} \
  --dbpassword pwd \
  --mail-from ${MAIL_FROM} \
  --smtp-host ${SMTP_HOST} \
  --dbapwd pwd

if [ "$PERFORM_DATABASE_UPGRADE" = yes ]; then
	voms-configure upgrade --vo ${VO_0_NAME}
fi

# Reconfigure VO 1
voms-configure install --vo ${VO_1_NAME} \
  --core-port ${VO_1_PORT} \
  --hostname ${LOCAL_HOSTNAME} \
  --dbusername ${VO_1_NAME} \
  --dbpassword pwd \
  --mail-from ${MAIL_FROM} \
  --smtp-host ${SMTP_HOST} \
  --dbapwd pwd

if [ "$PERFORM_DATABASE_UPGRADE" = yes ]; then
	voms-configure upgrade --vo ${VO_1_NAME}
fi

# Restart the VOMS services
service voms restart
service voms-admin restart

echo "Done."
