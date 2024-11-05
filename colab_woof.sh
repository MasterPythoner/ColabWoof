#!/bin/bash

usage() {
    echo "Usage: $0 ISO|PUPPY_SFS DEVX_SFS SHARE [bashrc]" >&2
    exit 1
}

[ $# -ne 3 -a $# -ne 4 ] && usage
([ ! -f "$1" ] || [ ! -f "$2" ] || [ ! -d "$3" ]) && usage

# Create mount points in /content which is writable in Colab
BASE_DIR="/content/woof_mounts"
ISO_MNT="$BASE_DIR/iso_mount"
SFS_MNT="$BASE_DIR/sfs_mount"
DEVX_MNT="$BASE_DIR/devx_mount"
WORK_DIR="$BASE_DIR/work"

# Cleanup function
cleanup() {
    cd /
    fusermount -u $ISO_MNT 2>/dev/null
    fusermount -u $SFS_MNT 2>/dev/null
    fusermount -u $DEVX_MNT 2>/dev/null
    rm -rf $BASE_DIR
}

# Setup clean environment
cleanup
mkdir -p $ISO_MNT $SFS_MNT $DEVX_MNT $WORK_DIR

# First, let's ensure we have the tools we need
apt-get install -y squashfuse fuseiso

echo "Mounting ISO file..."
if [ "${1#*.iso}" = "$1" ]; then
    # If it's an SFS file
    echo "Mounting SFS file directly..."
    squashfuse "$1" $SFS_MNT || exit 1
else
    # If it's an ISO file
    echo "Mounting ISO file..."
    fuseiso "$1" $ISO_MNT || exit 1
    # Find and mount the puppy SFS inside the ISO
    PUPPY_SFS=$(find $ISO_MNT -name "puppy_*.sfs" -type f)
    if [ -n "$PUPPY_SFS" ]; then
        echo "Found puppy SFS: $PUPPY_SFS"
        squashfuse "$PUPPY_SFS" $SFS_MNT || exit 1
    else
        echo "No puppy SFS found in ISO!"
        exit 1
    fi
fi

echo "Mounting DEVX SFS..."
squashfuse "$2" $DEVX_MNT || exit 1

echo "Setting up work directory..."
# Create necessary directories
mkdir -p "$WORK_DIR/"{etc,root,share}

# Copy files with error checking
if [ -d "$SFS_MNT" ]; then
    echo "Copying SFS contents..."
    cp -rv $SFS_MNT/* $WORK_DIR/ || echo "Warning: Some SFS files may not have copied"
fi

if [ -d "$DEVX_MNT" ]; then
    echo "Copying DEVX contents..."
    cp -rv $DEVX_MNT/* $WORK_DIR/ || echo "Warning: Some DEVX files may not have copied"
fi

if [ -d "$3" ]; then
    echo "Copying share directory..."
    cp -rv "$3" "$WORK_DIR/share/" || echo "Warning: Some share files may not have copied"
fi

# Set up basic environment
if [ -f /etc/resolv.conf ]; then
    cp -v /etc/resolv.conf "$WORK_DIR/etc/"
fi

if [ -e "$XAUTHORITY" ]; then
    cp -v $XAUTHORITY "$WORK_DIR/root/.Xauthority"
fi

# Set up trap before changing directory
trap cleanup EXIT

echo "Changing to work directory..."
cd $WORK_DIR

echo "Starting shell..."
export PS1="(Colab Woof) \w # "
/bin/bash
