KERNCONF=IMX6
TARGET_ARCH=armv6
IMAGE_SIZE=$((1024 * 1000 * 1000))
CUBOX_I_UBOOT_SRC=${TOPDIR}/u-boot-imx6

#
# 3 partitions, a reserve one for uboot, a FAT one for the boot loader and a UFS one
#
# the kernel config (CUBOX_I.common) specifies:
# U-Boot stuff lives on slice 1, FreeBSD on slice 2.
# options         ROOTDEVNAME=\"ufs:mmcsd0s2a\"
#
cubox_i_partition_image ( ) {
    disk_partition_mbr
    cubox_i_uboot_install
    disk_fat_create 50m 16 16384
    disk_ufs_create
}
strategy_add $PHASE_PARTITION_LWW cubox_i_partition_image

#
# CuBox-i uses U-Boot.
#
cubox_i_check_uboot ( ) {
	# Crochet needs to build U-Boot.

    uboot_set_patch_version ${CUBOX_I_UBOOT_SRC} ${CUBOX_I_UBOOT_PATCH_VERSION}

    uboot_test \
        CUBOX_I_UBOOT_SRC \
        "$CUBOX_I_UBOOT_SRC/board/solidrun/mx6_cubox-i/Makefile"
    strategy_add $PHASE_BUILD_OTHER uboot_patch ${CUBOX_I_UBOOT_SRC} `uboot_patch_files`
    strategy_add $PHASE_BUILD_OTHER uboot_configure $CUBOX_I_UBOOT_SRC mx6_cubix-i_config
    strategy_add $PHASE_BUILD_OTHER uboot_build $CUBOX_I_UBOOT_SRC
}
strategy_add $PHASE_CHECK cubox_i_check_uboot

#
# install uboot
#
cubox_i_uboot_install ( ) {
    echo Installing U-Boot to /dev/${DISK_MD}
    dd if=${CUBOX_I_UBOOT_SRC}/SPL of=/dev/${DISK_MD} bs=1K seek=1
    dd if=${CUBOX_I_UBOOT_SRC}/u-boot.img of=/dev/${DISK_MD} bs=1K seek=42
}

#
# ubldr
#
strategy_add $PHASE_BUILD_OTHER freebsd_ubldr_build UBLDR_LOADADDR=0x88000000
strategy_add $PHASE_BOOT_INSTALL freebsd_ubldr_copy_ubldr ubldr

#
# uEnv
#
cubox_i_install_uenvtxt(){
    echo "Installing uEnv.txt"
    cp ${BOARDDIR}/files/uEnv.txt .
}
#strategy_add $PHASE_BOOT_INSTALL cubox_i_install_uenvtxt

#
# DTS to FAT file system
#
cubox_i_install_dts_fat(){
    echo "Installing DTS to FAT"
    freebsd_install_fdt cubox_i-quad.dts cubox_i-quad.dts
    freebsd_install_fdt cubox_i-quad.dts cubox_i-quad.dtb
}
#strategy_add $PHASE_BOOT_INSTALL cubox_i_install_dts_fat

#
# DTS to UFS file system. This is in PHASE_FREEBSD_BOARD_POST_INSTALL b/c it needs to happen *after* the kernel install
#
cubox_i_install_dts_ufs(){
    echo "Installing DTS to UFS"
    freebsd_install_fdt cubox_i-quad.dts boot/kernel/cubox_i-quad.dts
    freebsd_install_fdt cubox_i-quad.dts boot/kernel/cubox_i-quad.dtb
}
strategy_add $PHASE_FREEBSD_BOARD_POST_INSTALL cubox_i_install_dts_ufs

#
# kernel
#
strategy_add $PHASE_FREEBSD_BOARD_INSTALL board_default_installkernel .
strategy_add $PHASE_FREEBSD_BOARD_INSTALL freebsd_ubldr_copy_ubldr_help boot

#
# Make a /boot/msdos directory so the running image
# can mount the FAT partition.  (See overlay/etc/fstab.)
#
strategy_add $PHASE_FREEBSD_BOARD_INSTALL mkdir boot/msdos

#
#  build the u-boot scr file
#
strategy_add $PHASE_BOOT_INSTALL uboot_mkimage ${CUBOX_I_UBOOT_SRC} "files/boot.txt" "boot.scr"

