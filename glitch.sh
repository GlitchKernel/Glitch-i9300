#!/bin/bash

# CM10 repo path :
repo=~/android/system

# Glitch kernel build-script parameters :
#
# "device" : build for a supported device (i9300).
# You can list all devices you want to build, separated by a space.
#
# clean : clean the build directory.

export CM10_REPO=$repo

CCACHE=ccache

export CROSS_PREFIX="$CCACHE /opt/toolchains/arm-eabi-4.6/bin/arm-linux-androideabi-"

setup ()
{
    if [ x = "x$CM10_REPO" ] ; then
        echo "Android build environment must be configured"
        exit 1
    fi
    . "$CM10_REPO"/build/envsetup.sh

#   Arch-dependent definitions
    case `uname -s` in
        Darwin)
            KERNEL_DIR="$(dirname "$(greadlink -f "$0")")"
            CROSS_PREFIX="$ANDROID_BUILD_TOP/prebuilt/darwin-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
            ;;
        *)
            KERNEL_DIR="$(dirname "$(readlink -f "$0")")"
            CROSS_PREFIX="$CROSS_PREFIX"
	    INITRAMFS="$KERNEL_DIR/release/build"
            ;;
    esac

    BUILD_DIR="../glitch-build/kernel"
    MODULES=("net/dns_resolver/dns_resolver.ko" "fs/cifs/cifs.ko" "drivers/scsi/scsi_wait_scan.ko" "drivers/net/wireless/btlock/btlock.ko" "drivers/net/wireless/bcmdhd/dhd.ko" "crypto/md4.ko" "arch/arm/mvp/pvtcpkm/pvtcpkm.ko" "arch/arm/mvp/mvpkm/mvpkm.ko" "arch/arm/mvp/commkm/commkm.ko")

    if [ x = "x$NO_CCACHE" ] && ccache -V &>/dev/null ; then
        CCACHE=ccache
        CCACHE_BASEDIR="$KERNEL_DIR"
        CCACHE_COMPRESS=1
        CCACHE_DIR="$CM10_REPO/kernel/samsung/.ccache"
        export CCACHE_DIR CCACHE_COMPRESS CCACHE_BASEDIR
    else
        CCACHE=""
    fi

}

build ()
{

formodules=$repo/kernel/samsung/glitch-build/kernel/i9300

    local target=i9300
    echo "Building for i9300"
    local target_dir="$BUILD_DIR/i9300"
    local module
    rm -fr "$target_dir"
    mkdir -p "$target_dir"

    mka -C "$KERNEL_DIR" O="$target_dir" cyanogenmod_i9300_defconfig HOSTCC="$CCACHE gcc"
    mka -C "$KERNEL_DIR" O="$target_dir" HOSTCC="$CCACHE gcc" CROSS_COMPILE="$CCACHE $CROSS_PREFIX" zImage modules

[[ -d release ]] || {
	echo "must be in kernel root dir"
	exit 1;
}

echo "creating boot.img"

mkdir -p $KERNEL_DIR/release/build/lib/modules/

cd $target_dir

find -name '*.ko' -exec cp -av {} $KERNEL_DIR/release/build/lib/modules/ \;
/opt/toolchains/arm-eabi-4.6/bin/arm-linux-androideabi-strip --strip-unneeded $KERNEL_DIR/release/build/lib/modules/*

cd $INITRAMFS

find | fakeroot cpio -H newc -o > $INITRAMFS.cpio 2>/dev/null
ls -lh $INITRAMFS.cpio
gzip -9 $INITRAMFS.cpio

cd $KERNEL_DIR

./mkbootimg --kernel $target_dir/arch/arm/boot/zImage --ramdisk $INITRAMFS.cpio.gz --board smdk4x12 --base 0x10000000 --pagesize 2048 --ramdiskaddr 0x11000000 -o $KERNEL_DIR/release/boot.img

echo "packaging it up"

cd release && {

mkdir -p $KERNEL_DIR/release/Flashable-i9300

REL=CM10-i9300-Glitch-$(date +%Y%m%d.%H%M).zip
	
	zip -q -r ${REL} system boot.img META-INF
	sha256sum ${REL} > ${REL}.sha256sum
	mv ${REL}* $KERNEL_DIR/release/Flashable-i9300/
}

cd $KERNEL_DIR/release

rm boot.img
rm -r build/lib
rm -rf build.cpio
rm -rf build.cpio.gz
echo ${REL}
}
    
setup

if [ "$1" = clean ] ; then
    rm -fr "$BUILD_DIR"/*
    echo "Old build cleaned"

else

time {

    build i9300

}
fi
