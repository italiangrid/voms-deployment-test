#!/bin/bash

export DEFAULT_EMI2_RELEASE_PACKAGE=http://emisoft.web.cern.ch/emisoft/dist/EMI/2/sl6/x86_64/base/emi-release-2.0.0-1.sl6.noarch.rpm
export DEFAULT_EMI_REPO=http://eticssoft.web.cern.ch/eticssoft/mock/emi-3-rc-sl6.repo
export DEFAULT_VOMS_REPO=http://radiohead.cnaf.infn.it:9999/view/REPOS/job/repo_voms_SL6/lastSuccessfulBuild/artifact/voms.repo

# Do MySQL deployment tests by default
export VOMS_METAPACKAGE=emi-voms-mysql

# Fill the env below with oracle account password
# export ORACLE_PASSWORD=

export ORACLE_DIST=sl6/x86_64
