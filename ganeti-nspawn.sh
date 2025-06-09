#!/bin/sh -e

if [ -e etc/os-release ] ; then
	clone=$(pwd)
elif [ -e etc/hostname ] ; then
	clone=$(pwd)
else
	echo "FATAL: no os install in pwd $(pwd)"
	exit 1
fi

echo "# directory $clone"

# save directory name inside instance fs
basename $clone > $clone/etc/hostname.dir
#echo cp ~dpavlin/ssl-expire-verify.sh $clone/root/

instance=$( basename $clone | sed 's/-0-.*$//' )
# strip date from instance name without disk number
instance=$( basename $instance | sed 's/-20[0-9][0-9]-.*$//' )
hostname=$( cat $clone/etc/hostname | sed 's/^CLONE-//' )
# just start of hostname for interface prefix
hostname_if=$( echo $hostname | cut -d. -f1 | cut -d- -f1 )
# if same as existing add _ at end
while [ $( brctl show | grep $hostname_if | wc -l ) -gt 1 ] ; do
	hostname_if=${hostname_if}_
done

grep link: /zamd/ganeti/*-instances/$instance*  | sed 's/^.*link: //' | cat -n | tee /dev/shm/$instance.br

# add bridges
#cat /dev/shm/deenes.ffzg.hr.br | awk '{ print $2 }' | xargs -i sh -cx 'brctl show {} || brctl addbr {}'

if [ -e $clone/etc/network/interfaces ] ; then
	# Debian
	grep -A 3 auto $clone/etc/network/interfaces \
	| grep -E '(auto eth|auto ens|bridge_ports)' | cut -d' ' -f2 | cut -d: -f1 | uniq | cat -n | tee /dev/shm/$instance.eth
elif [ -d $clone/etc/sysconfig/network-scripts ] ; then
	# RedHat
	cat etc/sysconfig/network-scripts/ifcfg-* | grep DEVICE= | grep -v lo | cut -d= -f2 | cat -n | tee /dev/shm/$instance.eth
else
	echo "ERROR: network configuration not supported"
	exit 1
fi

echo -n "systemd-nspawn --directory /$clone --hostname=\"$hostname\" \$@ " > /dev/shm/$instance.nspawn

join /dev/shm/$instance.br /dev/shm/$instance.eth | tee /dev/shm/$instance.network

if [ "$instance" = "mudrac" ] ; then
	echo "FIXUP owerride mudrac eth1010 to br1010"
	echo "1 br1010 eth1010" > /dev/shm/mudrac.network
fi

cat /dev/shm/$instance.network \
| awk -v hostname=$hostname -v if_name=$( echo $hostname | head -c 8 ) '{ print "--network-veth-extra "if_name"-"$2":"$3 }' | xargs echo >> /dev/shm/$instance.nspawn

chmod 755 /dev/shm/$instance.nspawn
ls -al /dev/shm/$instance.nspawn

sh -x /dev/shm/$instance.nspawn $@
