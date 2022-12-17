#!/bin/sh -e

clone=/zamd/clone/deenes.ffzg.hr-0-2022-12-16
if [ -e etc/os-release ] ; then
	clone=$(pwd)
fi

instance=$( basename $clone | sed 's/-0-.*$//' )
hostname=$( cat $clone/etc/hostname | sed 's/^CLONE-//' )
# just start of hostname for interface prefix
hostname_if=$( echo $hostname | cut -d. -f1 | cut -d- -f1 )
# if same as existing add _ at end
while [ $( brctl show | grep $hostname_if | wc -l ) -gt 1 ] ; do
	hostname_if=${hostname_if}_
done

grep link: /zamd/ganeti/*-instances/$instance  | cut -d: -f2 | cat -n | tee /dev/shm/$instance.br

# add bridges
#cat /dev/shm/deenes.ffzg.hr.br | awk '{ print $2 }' | xargs -i sh -cx 'brctl show {} || brctl addbr {}'

grep -A 3 auto $clone/etc/network/interfaces \
	| grep -E '(auto eth|bridge_ports)' | cut -d' ' -f2 | cut -d: -f1 | cat -n | tee /dev/shm/$instance.eth

echo -n "systemd-nspawn --directory /$clone \$@ " > /dev/shm/$instance.nspawn

join /dev/shm/$instance.br /dev/shm/$instance.eth | tee /dev/shm/$instance.nettwork \
	| awk -v hostname=$hostname_if '{ print "--network-veth-extra "hostname"-"$2":"$3 }' | xargs echo >> /dev/shm/$instance.nspawn

chmod 755 /dev/shm/$instance.nspawn
sh -x /dev/shm/$instance.nspawn
