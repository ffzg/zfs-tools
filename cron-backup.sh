#!/bin/sh -xe

# add authorized key on ganeti master node with
# command="/srv/gnt-info/gnt-lv-snap-rsync.sh -" ssh-rsa

# we need to disable all host key checking since masterfailover from one node to another on ganeti will change this keys
/srv/zfs-tools/backup-instances-today.sh | xargs -i echo 'echo {} | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/lib30-id_rsa root@cluster.gnt.ffzg.hr | tee "/dev/shm/cron.{}.log"' | tee /dev/shm/cron.sh
sh -xe /dev/shm/cron.sh

export backup=oscar
/srv/zfs-tools/backup-instances-today.sh | xargs -i echo 'echo {} | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/oscar-lv-snap-id_rsa root@oscar.gnt.ffzg.hr | tee "/dev/shm/cron.{}.log"' | tee /dev/shm/cron-$backup.sh
sh -xe /dev/shm/cron-$backup.sh

/srv/zfs-tools/diskrsync.sh

/srv/zfs-tools/zfs-list.pl | tee /dev/shm/zfs-list.txt

