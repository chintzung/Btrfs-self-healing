#!/bin/bash
f0="btrfstestblockdevicefile0"
f1="btrfstestblockdevicefile1"
ft="btrfstestfile"
loop0="/dev/loop0"
loop1="/dev/loop1"
mount_dir="/mnt/btrfstestdir"
size="1g"
token1="36bbf48aa6645646fbaa7f25b64224fb3399ad40bc706c79bb8276096e3c9e8f"
token2="36bbf48aa6645646fbaa7f25b64224fb4399ad40bc706c79bb8276096e3c9e8f"
FALLOCATE="fallocate"

f_mount() {
    echo "Mounting..." && \
    sudo losetup $loop0 $f0 && \
    sudo losetup $loop1 $f1 && \
    if ! [[ -z $1 ]] ; then
        sudo mkfs.btrfs -f -m raid1 -d raid1 -q $loop0 $loop1
    fi
    mkdir $mount_dir && \
    sudo mount $loop0 $mount_dir
}

f_umount() {
    echo "Unmounting..." && \
    sudo umount $loop0 && \
    sudo rmdir $mount_dir && \
    sudo losetup -d $loop0
    sudo losetup -d $loop1
}

echo "Allocating file for test block device..." && \
$FALLOCATE -l $size $f0 && \
$FALLOCATE -l $size $f1 && \
f_mount 1 && \
echo "Generating test file..." && \
dd if=/dev/urandom of="${ft}1" bs=1M count=400 status=none && \
echo $token1 > "${ft}2" && \
dd if=/dev/urandom of="${ft}3" bs=1M count=400 status=none && \
sudo sh -c "cat ${ft}1 ${ft}2 ${ft}3 > ${mount_dir}/${ft}" && \
rm "${ft}1" "${ft}2" "${ft}3" && \
echo "Calculating original hash of the file..." && \
sha256sum "${mount_dir}/${ft}" && \
f_umount && \
echo "Patching the file in the block device file..." && \
sed -i "s/${token1}/${token2}/g" $f0 && sync && \
f_mount && \
echo "btrfs scrub...." && \
btrfs scrub start -B ${mount_dir} && \
echo "Trying to read the file..." && \
sha256sum "${mount_dir}/${ft}"
echo "Cleaning up..." && \
f_umount && \
rm $f0 && \
rm $f1 && \
echo "All clear!"
