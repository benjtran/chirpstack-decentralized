#!/bin/bash
/usr/sbin/sshd
bash /loracluster/chirpstack_install.sh
tail -f /dev/null