#!/bin/bash

GPG="gpg -e -r me@example.com"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <HDFS mount point> <HDFS backup path> <HDFS backup folder>"
    exit 10
fi

root="$1"
path="$2"
name="$3"

tar -cvz -f - -C "${root}/${path}" "${name}" | ${GPG} | stream2gdrive --parent "System Backups" put - -o "hbase-${name}.tar.gz.pgp"
