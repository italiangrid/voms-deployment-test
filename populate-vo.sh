#!/bin/bash
#
# This script is meant to be run with VO admistrator privileges
# to configure the fixture for the test VO emi2to3. This script
# assumes that the igi-test-ca RPM is installed in the machine where
# it is run

[ $# -eq 1 ] || ( echo "Usage: $0 VO_NAME"; exit 1 ) 

# Where test certs are looked for
TEST_CERTS_PATH=/usr/share/igi-test-ca

# Name of the VO which will get the fixture
VO=$1

get_cert(){

        echo "$TEST_CERTS_PATH/$1.cert.pem"
}

TEST0_CERT=`get_cert test0`
TEST1_CERT=`get_cert test1`
PARENS=`get_cert dn_with_parenthesis`

G1=/$VO/G1
G2=/$VO/G2
G3=/$VO/G2/G3
G4=/$VO/G1/G4
G5=/$VO/G1/G4/G5

voms-admin --vo $VO \
        create-user $TEST0_CERT \
        create-user $TEST1_CERT \
        create-user $PARENS \
        create-group $G1 \
        create-group $G2 \
        create-group $G3 \
        create-group $G4 \
        create-group $G5 \
        create-role R1 \
        create-role R2 \
        create-role R3 \
        add-member $G1 $TEST0_CERT \
        add-member $G3 $TEST0_CERT \
        add-member $G2 $TEST1_CERT \
        add-member $G5 $TEST1_CERT \
        assign-role $G1 R1 $TEST0_CERT  \
        assign-role $G2 R1 $TEST0_CERT
