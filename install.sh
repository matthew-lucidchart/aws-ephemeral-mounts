#!/bin/bash

if [ $(whoami) != "root" ]; then
    echo "Must be run as root. Try:"
    echo "sudo $*"
    exit 1
fi

/usr/bin/apt-get update
/usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get -y install lvm2 xfsprogs cryptsetup

for module in dm-crypt aes rmd160; do
    [ -z "$(grep "^$module$" /etc/modules)" ] && /bin/echo "$module" | /usr/bin/tee -a /etc/modules
    /sbin/modprobe "$module"
done

