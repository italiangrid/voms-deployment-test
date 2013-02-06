# VOMS deployment test scripts

This repo hosts the VOMS deployment tests scripts used in the EMI3 certification process.

## Requirements

These scripts must be executed as root on a clean SL5, SL6 or Debian6 machine with SELINUX and firewall
disabled.

The IGI test CA RPM package must be installed.

## Deployment tests 

The clean installation scripts test a new VOMS installation:

```bash
[root@host ~] wget --no-check-certificate https://raw.github.com/valerioventuri/voms-deployment-test/master/emi3-setup-sl6.sh
[root@host ~] wget --no-check-certificate https://raw.github.com/valerioventuri/voms-deployment-test/master/emi-voms-clean-deployment.sh
```

Change preferences in the `emi3-setup.sl6.sh` depending on the deployment that you're testing (emi-voms-mysql vs emi-voms-oracle)
and issue the following commands:

```
[root@host ~] source emi3-setup-sl6.sh
[root@host ~] sh emi-voms-clean-deployment.sh
```

Follow the same instructions for the upgrade and run the following command:

```bash
[root@host ~] sh emi-voms-mysql-upgrade-deployment.sh
```
