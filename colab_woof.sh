#!/bin/bash

usage() {
    echo "Usage: $0 ISO|PUPPY_SFS DEVX_SFS SHARE [bashrc]" >&2
    exit 1
}

[ $# -ne 3 -a $# -ne 4 ] && usage
([ ! -f "$1" ] || [ ! -f "$2" ] || [ ! -d "$3" ]) && usage

# Create mount points in /content which is writable in Colab
BASE_DIR="/content/woof_mounts"
SFS_MNT="$BASE_DIR/sfs_mount"
DEVX_MNT="$BASE_DIR/devx_mount"
WORK_DIR="$BASE_DIR/work"

# Cleanup function
cleanup() {
    cd /
    fusermount -u $SFS_MNT 2>/dev/null
    fusermount -u $DEVX_MNT 2>/dev/null
    rm -rf $BASE_DIR
}

# Setup clean environment
cleanup
mkdir -p $SFS_MNT $DEVX_MNT $WORK_DIR

# Mount the SFS files using squashfuse (which works in Colab)
if [ "${1#*.sfs}" = "$1" ]; then
    # For ISO files
    apt-get install -y p7zip-full
    7z x "$1" -o"$WORK_DIR/iso_contents"
    squashfuse "$WORK_DIR/iso_contents/puppy_*.sfs" $SFS_MNT
else
    # For SFS files directly
    squashfuse "$1" $SFS_MNT
fi

squashfuse "$2" $DEVX_MNT

# Copy necessary files to work directory
cp -r $SFS_MNT/* $WORK_DIR/
cp -r $DEVX_MNT/* $WORK_DIR/
cp -r "$3" "$WORK_DIR/share"

# Set up basic environment
cp /etc/resolv.conf "$WORK_DIR/etc/"
[ -e "$XAUTHORITY" ] && cp $XAUTHORITY "$WORK_DIR/root/.Xauthority"

# Change to work directory and start shell
cd $WORK_DIR
/bin/bash --rcfile /etc/bashrc

# Cleanup on exit
trap cleanup EXIT
