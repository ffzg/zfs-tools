#!/bin/sh -xe

# add authorized key on ganeti master node with
# command="/srv/gnt-info/gnt-lv-snap-rsync.sh -" ssh-rsa

/srv/zfs-tools/backup-instances-today.sh | xargs -i echo 'echo {} | ssh -i /root/.ssh/lib30-id_rsa root@cluster.gnt.ffzg.hr | tee "/dev/shm/cron.{}.log"' | tee /dev/shm/cron.sh
sh -xe /dev/shm/cron.sh

export backup=oscar
/srv/zfs-tools/backup-instances-today.sh | xargs -i echo 'echo {} | ssh -i /root/.ssh/oscar-lv-snap-id_rsa root@oscar.net.ffzg.hr | tee "/dev/shm/cron.{}.log"' | tee /dev/shm/cron-$backup.sh
sh -xe /dev/shm/cron-$backup.sh

/srv/zfs-tools/diskrsync.sh

/srv/zfs-tools/zfs-list.pl | tee /dev/shm/zfs-list.txt


ssh lib20 /srv/zfs-tools/diskrsync.sh

ssh lib20 /lib20/zpool-backup/cloud.sh
