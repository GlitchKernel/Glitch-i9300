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

# Toolchain :
export CROSS_PREFIX="$repo/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6/bin/arm-eabi-"

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
            CROSS_PREFIX="$repo/prebuilts/gcc/darwin-x86/arm/arm-eabi-4.6/bin/arm-eabi-"
            ;;
        *)
            KERNEL_DIR="$(dirname "$(readlink -f "$0")")"
            CROSS_PREFIX="$CROSS_PREFIX"
            ;;
    esac

    BUILD_DIR="../glitch-build/kernel"

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

echo "copying modules and zImage"

mkdir -p $KERNEL_DIR/release/zimage/system/lib/modules/

cd $target_dir

find -name '*.ko' -exec cp -av {} $KERNEL_DIR/release/zimage/system/lib/modules/ \;
"$CROSS_PREFIX"strip --strip-unneeded $KERNEL_DIR/release/zimage/system/lib/modules/*

cd $KERNEL_DIR

mv $target_dir/arch/arm/boot/zImage $KERNEL_DIR/release/zimage/kernel/zImage

echo "packaging it up"

cd release/zimage && {

mkdir -p $KERNEL_DIR/release/Flashable-i9300

REL=CM10-i9300-Glitch-$(date +%Y%m%d.%H%M).zip
	
	zip -q -r ${REL} kernel META-INF system
	sha256sum ${REL} > ${REL}.sha256sum
	mv ${REL}* $KERNEL_DIR/release/Flashable-i9300/

rm kernel/zImage
rm -r system
}

cd $KERNEL_DIR

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
