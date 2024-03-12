#!/bin/sh -xe

keep=14

zfs_destroy() {
	path=$1
	name=$( basename $path )

	zfs list -r -t snapshot -o name -H $path > /tmp/zfs.$name
	echo -n "$name snapshots: "
	wc -l /tmp/zfs.$name
	tail -$keep /tmp/zfs.$name > /tmp/zfs.$name.keep
	grep -v -f /tmp/zfs.$name.keep /tmp/zfs.$name > /tmp/zfs.$name.destroy
	echo -n "$name destroy:   "
	wc -l /tmp/zfs.$name.destroy
	cat /tmp/zfs.$name.destroy | xargs -i zfs destroy -v {}
}

zfs_destroy zamd/dpavlin/nuc
