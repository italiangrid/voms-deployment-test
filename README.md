# VOMS deployment test scripts

This repo hosts the VOMS deployment tests scripts used in the EMI3 certification process.

## Requirements

These scripts must be executed as root on a clean SL5, SL6 or Debian6 machine with SELINUX and firewall
disabled.

The IGI test CA RPM package must be installed.

## Clean installation 

The clean installation scripts test a new VOMS installation:

```bash
[root@host ~] wget --no-check-certificate https://raw.github.com/valerioventuri/voms-deployment-test/master/emi3-setup-sl6.sh
[root@host ~] wget --no-check-certificate https://raw.github.com/valerioventuri/voms-deployment-test/master/emi-voms-mysql-clean-deployment.sh
[root@host ~] source emi3-setup-sl6.sh
[root@host ~] sh emi-voms-mysql-clean-deployment.sh
```

## Upgrade installation

The upgrade installation first install & configure the latest EMI 2 VOMS release and
then upgrade such deployment:

```bash
[root@host ~] wget --no-check-certificate https://raw.github.com/valerioventuri/voms-deployment-test/master/emi3-setup-sl6.sh
[root@host ~] wget --no-check-certificate https://raw.github.com/valerioventuri/voms-deployment-test/master/emi-voms-mysql-clean-deployment.sh
[root@host ~] source emi3-setup-sl6.sh
[root@host ~] sh emi-voms-mysql-upgrade-deployment.sh
```

