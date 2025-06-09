#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error when substituting.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status.

# --- Configuration ---
INSTANCE_NAME="kompk.ffzg.hr"
ZFS_DISK_PATH="zamd/cluster/${INSTANCE_NAME}/0"
CLONE_BASE_PATH="zamd/clone"
OUTPUT_DIR="/zamd/clone/mysql-diffs"

# THE FIX: Add options for diff-friendly output.
# --skip-extended-insert: One INSERT statement per row.
# --complete-insert: Include column names in INSERT statements for robustness.
MYSQLDUMP_OPTS="--all-databases --single-transaction --skip-extended-insert --complete-insert --quick --routines --triggers"

# --- Script Logic ---
mkdir -p "$OUTPUT_DIR"

cleanup() {
    echo "---"
    echo "Running cleanup..."
    for clone_name in "$CLONE_NAME_START" "$CLONE_NAME_END"
    do
        if [ -n "$clone_name" ] && zfs list -H -o name "$clone_name" &>/dev/null; then
            echo "Destroying ZFS clone: $clone_name"
            umount -R "/$clone_name" 2>/dev/null || true
            zfs destroy -f "$clone_name" || true
        fi
    done
    echo "Cleanup finished."
}

get_dump_for_date() {
    local date="$1"
    local output_file="$2"
    local snapshot_full_path
    local clone_path="${CLONE_BASE_PATH}/${INSTANCE_NAME}-${date}"
    local payload_script_path="/$clone_path/root/mysql_dumper.sh"

    echo "---"
    echo "Processing date: $date"

    snapshot_full_path="${ZFS_DISK_PATH}@${date}"
    if ! zfs list -H -o name "$snapshot_full_path" &>/dev/null; then
        snapshot_full_path=$(zfs list -t snapshot -H -o name -S creation "${ZFS_DISK_PATH}" | grep "${date}" | tail -n1)
        if [ -z "$snapshot_full_path" ]; then
            echo "ERROR: Snapshot for date $date not found."
            exit 0
        fi
    fi
    echo "Found snapshot: $snapshot_full_path"
    zfs clone "$snapshot_full_path" "$clone_path"

    if [ "$date" == "$START_DATE" ]; then
        CLONE_NAME_START="$clone_path"
    else
        CLONE_NAME_END="$clone_path"
    fi

    echo "Modifying clone..."
    /srv/zfs-tools/ganeti-instance-modify.pl "/$clone_path" || true

    echo "Creating payload script inside the clone at $payload_script_path"
    cat <<EOF > "$payload_script_path"
#!/bin/bash
set -e
echo "  -> [Payload] Starting MySQL service..."
sh /etc/init.d/mysql start
echo "  -> [Payload] Waiting for MySQL service to be ready..."
count=0
while ! mysqladmin ping &>/dev/null; do
    sleep 1
    count=\$((count+1))
    if [ \$count -gt 30 ]; then
        echo "  -> [Payload] ERROR: Timed out waiting for MySQL service." >&2
        tail -n 50 /var/log/mysql/error.log >&2 || true
        exit 1
    fi
done
echo "  -> [Payload] MySQL service is ready. Creating dump..."
mysqldump --defaults-extra-file=/etc/mysql/debian.cnf $MYSQLDUMP_OPTS
echo "  -> [Payload] Stopping MySQL service..." >&2
sh /etc/init.d/mysql stop >/dev/null
EOF

    chmod +x "$payload_script_path"

    echo "Executing payload script from /root/ inside container..."
    (
        cd "/$clone_path" && /srv/zfs-tools/ganeti-nspawn.sh /root/mysql_dumper.sh
    ) > "$output_file"
    
    echo "Dump complete for $date."
}


# --- Main execution ---
CLONE_NAME_START=""
CLONE_NAME_END=""
trap cleanup EXIT

echo "---"

if [ "$#" -eq 2 ]; then
    START_DATE="$1"
    END_DATE="$2"
    echo "Manual Run: Creating diff from specified dates."
    echo "  Start Date: $START_DATE"
    echo "  End Date:   $END_DATE"
elif [ "$#" -eq 1 ]; then
    START_DATE="$1"
    END_DATE=$(date +%Y-%m-%d)
    echo "Manual Run: Creating diff from specified start date to today."
    echo "  Start Date: $START_DATE"
    echo "  End Date:   $END_DATE"
else
    echo "Automatic Run: Searching for the first missing daily diff..."
    START_DATE=""
    END_DATE=""
    for i in {0..365}; do
        current_end_date=$(date -d "today - $i days" +%Y-%m-%d)
        current_start_date=$(date -d "$current_end_date - 1 day" +%Y-%m-%d)
        current_diff_file="${OUTPUT_DIR}/diff-${INSTANCE_NAME}-${current_start_date}_to_${current_end_date}.patch"
        if [ -e "$current_diff_file" ]; then
            echo "Found existing diff: $current_diff_file. Checking previous day."
            continue
        else
            echo "Found task: Will create diff from $current_start_date to $current_end_date."
            START_DATE=$current_start_date
            END_DATE=$current_end_date
            break
        fi
    done
fi

if [ -z "$START_DATE" ]; then
    echo "All recent diffs are present. Nothing to do."
    exit 0
fi

DUMP_START="${OUTPUT_DIR}/dump-${INSTANCE_NAME}-${START_DATE}.sql"
DUMP_END="${OUTPUT_DIR}/dump-${INSTANCE_NAME}-${END_DATE}.sql"
DIFF_FILE="${OUTPUT_DIR}/diff-${INSTANCE_NAME}-${START_DATE}_to_${END_DATE}.patch"

if [ -e "$DUMP_START" ]; then
    echo "Found existing dump file for start date: $DUMP_START. Skipping."
else
    get_dump_for_date "$START_DATE" "$DUMP_START"
fi

if [ -e "$DUMP_END" ]; then
    echo "Found existing dump file for end date: $DUMP_END. Skipping."
else
    get_dump_for_date "$END_DATE" "$DUMP_END"
fi

echo "---"
echo "Creating diff between $START_DATE and $END_DATE..."
diff -u "$DUMP_START" "$DUMP_END" > "$DIFF_FILE" || true
echo "Diff created at: $DIFF_FILE"

echo "---"
echo "Script finished successfully."