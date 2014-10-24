#!/bin/bash
 
source common.sh

echo "emi-voms-mysql clean deployment test"

print_repo_information
install_test_ca_repo
install_emi_repo
install_voms_repo

# Clean yum database
execute "yum clean all"

install_cas

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

configure_container


# Configure info providers
execute 'voms-config-info-providers -s local -e'
 
# bdii needs ldap2.4 on SL5
if [ "$platform" = "SL5" ]; then
	configure_bdii
fi

# start bdii
execute 'service bdii start'

run_fetch_crl


execute 'service voms-admin start'
 
# wait a while
execute 'sleep 60'
 
# check voms-admin can list groups
execute "voms-admin --vo $vo list-groups"
 
# populate vo
execute "wget --no-check-certificate $populate_vo_script_url"
execute "sh populate-vo.sh $vo"

# Install voms clients
execute "yum -y install voms-clients3"

setup_voms_clients_configuration
setup_client_certificate

# start voms
execute 'service voms start'
execute 'sleep 30'

# VOMS proxy init test
execute "echo 'pass' | voms-proxy-init -voms $vo --pwstdin"

for i in `seq 1 10`; do
    execute "voms-proxy-init -voms $vo -noregen"
done
    
echo "VOMS succesfully deployed!"
