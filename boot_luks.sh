#! /bin/bash

### BEGIN INIT INFO
# Provides:          ephemeral
# Required-Start:    $syslog
# Required-Stop:     $syslog
# Should-Start:      
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Encrypt and mount ephemeral storage
# Description:       No daemon is created or managed. This script is a Lucid
#                    creation that mounts AWS ephemeral volumes as encrypted,
#                    striped devices.
### END INIT INFO

VG_NAME=ephemeral
KEYDIR=/var/cache/ephemeral-mount

. /lib/lsb/init-functions

ephemeral_start() {
    DEVICES=$(/bin/ls /dev/xvdb* /dev/xvdc* /dev/xvdd* /dev/xvde* 2>/dev/null)
    PVSCAN_OUT=$(/sbin/pvscan)

    for device in $DEVICES; do
        if [ -z "$(/bin/echo "$PVSCAN_OUT" | grep " $device ")" ]; then
            /bin/umount "$device"
            /bin/sed -e "/$(basename $device)/d" -i /etc/fstab
            /bin/dd if=/dev/zero of="$device" bs=1M count=10
            /sbin/pvcreate "$device"
        fi
    done

    if [ ! -d "/dev/$VG_NAME" ]; then
        /sbin/vgcreate "$VG_NAME" $DEVICES
    fi

    VGSIZE=$(/sbin/vgdisplay "$VG_NAME" | grep "Total PE" | sed -e "s/[^0-9]//g")

    # tmp/swap should be 15% of the volume up to 20G
    # NO STRIPING ON ANY VOLUMES!!!
    # for some reason, striping ephemeral volumes is slower than not striping.
    if [ $VGSIZE -gt 25600 ]; then
        [ ! -e "/dev/$VG_NAME/swap" ] && /sbin/lvcreate -l5120 -nswap "$VG_NAME"
        [ ! -e "/dev/$VG_NAME/tmp" ] && /sbin/lvcreate -l5120 -ntmp "$VG_NAME"
    else
        [ ! -e "/dev/$VG_NAME/swap" ] && /sbin/lvcreate -l15%VG -nswap "$VG_NAME"
        [ ! -e "/dev/$VG_NAME/tmp" ] && /sbin/lvcreate -l15%VG -ntmp "$VG_NAME"
    fi

    [ ! -e "/dev/$VG_NAME/mnt" ] && /sbin/lvcreate -l100%FREE -nmnt "$VG_NAME"

    /bin/mkdir -p "$KEYDIR"
    /bin/chmod 700 "$KEYDIR"

    # Do swap
    /bin/dd if=/dev/urandom of="$KEYDIR/swap.key" bs=4k count=1
    /sbin/cryptsetup luksFormat --batch-mode --key-file "$KEYDIR/swap.key" --cipher aes-cbc-essiv:sha256 --hash ripemd160 --key-size 256 "/dev/$VG_NAME/swap"
    /sbin/cryptsetup luksOpen --key-file "$KEYDIR/swap.key" "/dev/$VG_NAME/swap" swap
    /usr/bin/shred -u "$KEYDIR/swap.key"

    /sbin/mkswap -f /dev/mapper/swap
    /sbin/swapon /dev/mapper/swap

    # Do tmp
    /bin/dd if=/dev/urandom of="$KEYDIR/tmp.key" bs=4k count=1
    /sbin/cryptsetup luksFormat --batch-mode --key-file "$KEYDIR/tmp.key" --cipher aes-cbc-essiv:sha256 --hash ripemd160 --key-size 256 "/dev/$VG_NAME/tmp"
    /sbin/cryptsetup luksOpen --key-file "$KEYDIR/tmp.key" "/dev/$VG_NAME/tmp" tmp
    /usr/bin/shred -u "$KEYDIR/tmp.key"

    /sbin/mkfs.xfs -f /dev/mapper/tmp
    /bin/mkdir -p /tmp
    [ -z "$(mount | grep " on /tmp ")" ] && rm -rf /tmp/*
    /bin/mount -t xfs /dev/mapper/tmp /tmp
    /bin/chmod 1777 /tmp

    # We would do /mnt here, but we have to maintain whatever is on there from the last reboot.
    # /mnt will be formatted, opened, mounted, and handled entirely in chef.

    log_end_msg 0
} # ephemeral_start

ephemeral_stop() {
    /sbin/swapoff /dev/mapper/swap
    /bin/umount /tmp
    /bin/umount /mnt

    /sbin/cryptsetup luksClose swap
    /sbin/cryptsetup luksClose tmp
    /sbin/cryptsetup luksClose mnt
    sync

    # takes a second to turn off luks
    sleep 5

    /sbin/vgchange -an "$VG_NAME"
    
    log_end_msg 0
} # ephemeral_stop


case "$1" in
  start)
	log_daemon_msg "Mounting ephemeral volumes" "ephemeral"
        ephemeral_start
	;;

  stop)
	log_daemon_msg "Umounting ephemeral volumes" "ephemeral"
        ephemeral_stop
	;;

  *)
	echo "Usage: /etc/init.d/ephemeral-mount {start|stop}"
	exit 1
esac

exit 0

