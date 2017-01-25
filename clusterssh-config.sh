cat /dev/shm/backup.instances | cut -d" " -f1 | sort -u | xargs echo `hostname -s`
