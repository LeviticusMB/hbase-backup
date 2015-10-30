#!/bin/bash

# To use this script:
# hbase-backup-table.rb --db-table <tablename> /path/to/hbase-backup-cmd-ssh.sh user@remote.host /hdfs-nfs-mount-point

if [ $# -ne 4 ]; then
    echo "Usage: $0 <Remote SSH host> <HDFS mount point> <HDFS backup path> <HDFS backup folder>"
    exit 10
fi

host="$1"
root="$2"
path="$3"
name="$4"

tar -cvz -f - -C "${root}/${path}" "${name}" | ssh "${host}" "dd of='hbase-${name}@${HOSTNAME}.tar.gz'"
