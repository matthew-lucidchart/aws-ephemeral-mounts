aws-ephemeral-mounts
====================

AWS provides ephemeral volumes for most instance sizes. Once instance can have multiple ephemeral volumes. You're probably not using all of yours, are you? This repo is a set of scripts you can run on any AWS instance to setup LVM, LUKS, and mountpoints to get the most out of your ephemeral volumes.

What this script does is take all of the ephemeral volumes and stick them into an LVM volume group. Then it creates a logical volume for tmp (<20G), another for swap (<20G), and uses the remaining space for mnt. The tmp and mnt partitions get an XFS filesystem while the swap gets a swap filesystem. Finally, it mounts all the partitions where they go.

Instructions
------------

1. Launch a server. Make sure that the server has all of the ephemeral mounts specified in /dev/sd[bcde].
2. Upload and run the __install.sh__ script.
3. Upload the __boot.sh__ script to __/etc/init.d/ephemeral__.
4. Change permissions and ownership of the __/etc/init.d/ephemeral__ script.

	> sudo chown root:root /etc/init.d/ephemeral
	> sudo chmod 755 /etc/init.d/ephemeral

5. Run the script on startup.

	> sudo update-rc.d ephemeral defaults 00

6. Create an AMI from the instance. Make sure the AMI has all of the ephemeral mounts specified in /dev/sd[bcde].

Using LUKS
----------

LUKS can be used for encryption at rest. In this mode, an encryption key will be created, used, and shredded for tmp and swap partitions. The key is thrown away because of the temporary nature of these filesystems. The mnt partition, on the other hand, is intended to be long-lived (at least through reboots). For security, I have not included an encryption key for mnt. You should create your own key, and then luksFormat, luksOpen, mkfs.xfs, and mount /mnt. These steps are the same for the tmp partition in the script, for your reference.

If you want to use LUKS to encrypt your tmp, swap, and mnt partitions, replace boot.sh in step 3 with boot_luks.sh.

Supported Operating Systems
---------------------------

This script has been thoroughly tested using Ubuntu 12.04 on AWS. It is likely to work with any version of Ubuntu after 10.04. It may work with many versions of Linux (RedHat, CentOS, Debian, etc), but I have not tested it on those systems.


