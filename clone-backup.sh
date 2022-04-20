#!/bin/sh -xe

instance=$1

pool=$( zpool list -H -o name )
path=$( zfs list -o name | grep $instance/0 )
snap=$( zfs list -t snapshot -o name $path | tail -1 )
clone="$pool/clone/$instance-$( basename $snap | sed 's/@/-/g' )"
zfs clone $snap $clone
echo "$instance-clone" > /$clone/etc/hostname

echo "auto mv-bond0.60"            >> /$clone/etc/network/interfaces
echo "iface mv-bond0.60 inet dhcp" >> /$clone/etc/network/interfaces

perl -p -i -n -e 's/(listen )193.*:(\d+)/$1 $2/' /$clone/etc/nginx/sites-available/*

systemd-nspawn --boot --network-macvlan=bond0.60 --directory /$clone

echo "destroy with: zfs destroy $clone"
