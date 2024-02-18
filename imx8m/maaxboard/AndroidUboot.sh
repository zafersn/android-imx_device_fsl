#!/bin/bash

# hardcode this one again in this shell script
CONFIG_REPO_PATH=device/nxp

# import other paths in the file "common/imx_path/ImxPathConfig.mk" of this
# repository

while read -r line
do
	if [ "$(echo ${line} | grep "=")" != "" ]; then
		env_arg=`echo ${line} | cut -d "=" -f1`
		env_arg=${env_arg%:}
		env_arg=`eval echo ${env_arg}`

		env_arg_value=`echo ${line} | cut -d "=" -f2`
		env_arg_value=`eval echo ${env_arg_value}`

		eval ${env_arg}=${env_arg_value}
	fi
done < ${CONFIG_REPO_PATH}/common/imx_path/ImxPathConfig.mk

if [ "${AARCH64_GCC_CROSS_COMPILE}" != "" ]; then
	ATF_CROSS_COMPILE=`eval echo ${AARCH64_GCC_CROSS_COMPILE}`
else
	echo ERROR: \*\*\* env AARCH64_GCC_CROSS_COMPILE is not set
	exit 1
fi

build_m4_image()
{
	:
}

build_imx_uboot()
{
	echo Building i.MX U-Boot with firmware
	cp ${UBOOT_OUT}/u-boot-nodtb.$1 ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/
	cp ${UBOOT_OUT}/spl/u-boot-spl.bin ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/
	cp ${UBOOT_OUT}/tools/mkimage ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/mkimage_uboot
	cp ${UBOOT_OUT}/arch/arm/dts/imx8mq-evk.dtb  ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/
	cp ${FSL_PROPRIETARY_PATH}/linux-firmware-imx/firmware/hdmi/cadence/signed_hdmi_imx8m.bin  ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/
	cp ${FSL_PROPRIETARY_PATH}/linux-firmware-imx/firmware/ddr/synopsys/lpddr4_pmu_train* ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/

	# build ATF based on whether tee is involved
	make -C ${IMX_PATH}/arm-trusted-firmware/ PLAT=`echo $2 | cut -d '-' -f1` clean
	if [ `echo $2 | cut -d '-' -f2` = "trusty" ] && [ `echo $2 | rev | cut -d '-' -f1` != "uuu" ]; then
		cp ${FSL_PROPRIETARY_PATH}/fsl-proprietary/uboot-firmware/imx8m/tee-imx8mq.bin ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/tee.bin
		make -C ${IMX_PATH}/arm-trusted-firmware/ CROSS_COMPILE="${ATF_CROSS_COMPILE}" PLAT=`echo $2 | cut -d '-' -f1` bl31 -B IMX_ANDROID_BUILD=true SPD=trusty 1>/dev/null || exit 1
	else
		if [ -f ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/tee.bin ] ; then
			rm -rf ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/tee.bin
		fi
		if [ -f ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/tee.bin.lz4 ] ; then
			rm -rf ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/tee.bin.lz4
		fi
		make -C ${IMX_PATH}/arm-trusted-firmware/ CROSS_COMPILE="${ATF_CROSS_COMPILE}" PLAT=`echo $2 | cut -d '-' -f1` bl31 -B IMX_ANDROID_BUILD=true 1>/dev/null || exit 1
	fi
	cp ${IMX_PATH}/arm-trusted-firmware/build/`echo $2 | cut -d '-' -f1`/release/bl31.bin ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/bl31.bin

	make -C ${IMX_MKIMAGE_PATH}/imx-mkimage/ clean
	if [ `echo $2 | rev | cut -d '-' -f1 | rev` != "dual" ]; then
		make -C ${IMX_MKIMAGE_PATH}/imx-mkimage/ SOC=iMX8M flash_hdmi_spl_uboot || exit 1
		make -C ${IMX_MKIMAGE_PATH}/imx-mkimage/ SOC=iMX8M print_fit_hab || exit 1
	else
		make -C ${IMX_MKIMAGE_PATH}/imx-mkimage/ SOC=iMX8M flash_evk_dual_bootloader || exit 1
		make -C ${IMX_MKIMAGE_PATH}/imx-mkimage/ SOC=iMX8M PRINT_FIT_HAB_OFFSET=0x0 print_fit_hab || exit 1
	fi
	if [ `echo $2 | rev | cut -d '-' -f1 | rev` != "dual" ]; then
		cp ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/flash.bin ${UBOOT_COLLECTION}/u-boot-$2.imx
	else
		cp ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/flash.bin ${UBOOT_COLLECTION}/spl-$2.bin
		cp ${IMX_MKIMAGE_PATH}/imx-mkimage/iMX8M/u-boot-ivt.itb ${UBOOT_COLLECTION}/bootloader-$2.img
	fi
}

