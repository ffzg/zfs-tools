#!/bin/sh -e

keep=14

zfs_destroy() {
	path=$1
	name=$( basename $path )

	zfs list -r -t snapshot -o name -H $path > /tmp/zfs.$name
	echo -n "$name snapshots: "
	wc -l /tmp/zfs.$name
	tail -$keep /tmp/zfs.$name > /tmp/zfs.$name.keep
	if grep -v -f /tmp/zfs.$name.keep /tmp/zfs.$name > /tmp/zfs.$name.destroy ; then
		echo -n "$name destroy:   "
		wc -l /tmp/zfs.$name.destroy
		cat /tmp/zfs.$name.destroy | xargs -i zfs destroy -v {}
	else
		echo "$name no snapshots older than $keep days"
	fi
}

zfs_destroy zamd/dpavlin/nuc

zfs_destroy zamd/mglavica/mlinz/data
zfs_destroy zamd/mglavica/mlinz/data/rest
zfs_destroy zamd/mglavica/mlinz/docker
zfs_destroy zamd/mglavica/mlinz/home
zfs_destroy zamd/mglavica/mlinz/home/mglavica
zfs_destroy zamd/mglavica/mlinz/klin
zfs_destroy zamd/mglavica/mlinz/postgresql
zfs_destroy zamd/mglavica/mlinz/root
zfs_destroy zamd/mglavica/mlinz/srv
