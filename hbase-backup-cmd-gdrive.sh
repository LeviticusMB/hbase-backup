#!/bin/bash

# To use this script:
# hbase-backup-table.rb --db-table <tablename> /path/to/hbase-backup-cmd-gdrive.sh /hdfs-nfs-mount-point

if [ $# -ne 3 ]; then
    echo "Usage: $0 <HDFS mount point> <HDFS backup path> <HDFS backup folder>"
    exit 10
fi

root="$1"
path="$2"
name="$3"

tar -cvz -f - -C "${root}/${path}" "${name}" | stream2gdrive put - -o "hbase-${name}.tar.gz"
