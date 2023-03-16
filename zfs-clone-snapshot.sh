#!/bin/sh -xe

snapshot=$1
pool=$( zpool list -H -o name )

if [ -z "$snapshot" ]; then
	#host_disk=`zfs list -H -o name -r lib15/backup | grep '/[0-9]*$' | iselect --all --name="Select host and disk"`
	host_disk=`zfs list -H -r -o name $( ls -d /$pool/{cluster,oscar} | sed 's,/,,' ) | grep '/0$' | iselect --all --name="Select host and disk"`
	echo "# reading snapshots for $host_disk"
	snapshot=`zfs list -o name -r -t snapshot $host_disk | sort -r | iselect --all --name="Select snapshot date to diff"`
	test -z "$snapshot" && echo "no snapshot selected, aborting" && exit 1
fi

test -z "$snapshot" && echo "Usage: $0 zfs-snapshot" && exit 1

sudo zfs list -H -t snapshot -o name $snapshot | while read snapshot ; do
	echo "# clone $snapshot"
	clone=$( echo $snapshot | sed -e 's,^.*/cluster/,,' -e 's,^.*/oscar/,,' -e 's,/\([0-9]*\)@,-\1-,' )
	sudo zfs clone $snapshot $pool/clone/$clone || true

	# prefix hostname with CLONE-
	#echo CLONE-$clone.local > /$pool/clone/$clone/etc/hostname
	#echo 127.0.0.3 CLONE-$clone.local >> /$pool/clone/$clone/etc/hosts

	i_sh=/$pool/clone/$clone/i.sh
	cat <<__SHELL__ > $i_sh
#!/bin/sh -xe
	apt remove -y acpid
__SHELL__
	chmod 755 $i_sh

	systemd-nspawn --directory /$pool/clone/$clone /i.sh

	echo "## cd /$pool/clone/$clone ; /srv/zfs-tools/ganeti-nspawn.sh --boot"
done
