#!/bin/sh
export PLATFORM="TW"
export MREV="LP5.0"
export CURDATE=`date "+%m.%d.%Y"`
export MUXEDNAMELONG="KT-NOTE4-$MREV-$PLATFORM-$CARRIER-$CURDATE"
export MUXEDNAMESHRT="KT-NOTE4-$MREV-$PLATFORM-$CARRIER*"
export KTVER="--$MUXEDNAMELONG--"
export KERNELDIR=`readlink -f .`
export PARENT_DIR=`readlink -f ..`
export INITRAMFS_DEST=$KERNELDIR/kernel/usr/initramfs
export INITRAMFS_SOURCE=`readlink -f ..`/Ramdisks/$PLATFORM"_"$CARRIER"5.0"
export CONFIG_$PLATFORM_BUILD=y
export PACKAGEDIR=$PARENT_DIR/Packages/$PLATFORM
#Enable FIPS mode
#export USE_SEC_FIPS_MODE=true
export ARCH=arm
#export CROSS_COMPILE=/home/ktoonsez/cm/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7/bin/arm-eabi-
export CROSS_COMPILE=$PARENT_DIR/linaro4.9-a15/bin/arm-cortex_a15-linux-gnueabihf-
export ENABLE_GRAPHITE=true

time_start=$(date +%s.%N)

echo "Remove old Package Files"
rm -rf $PACKAGEDIR/*

echo "Setup Package Directory"
mkdir -p $PACKAGEDIR/system/app
mkdir -p $PACKAGEDIR/system/lib/modules
mkdir -p $PACKAGEDIR/system/etc/init.d

echo "Create initramfs dir"
mkdir -p $INITRAMFS_DEST

echo "Remove old initramfs dir"
rm -rf $INITRAMFS_DEST/*

echo "Copy new initramfs dir"
cp -R $INITRAMFS_SOURCE/* $INITRAMFS_DEST

echo "chmod initramfs dir"
chmod -R g-w $INITRAMFS_DEST/*
rm $(find $INITRAMFS_DEST -name EMPTY_DIRECTORY -print)
rm -rf $(find $INITRAMFS_DEST -name .git -print)

echo "Remove old zImage"
rm $PACKAGEDIR/zImage
rm arch/arm/boot/zImage
rm arch/arm/boot/zImage-dtb
rm arch/arm/boot/dt.img
rm arch/arm/boot/dts/*.dtb
rm arch/arm/boot/dts/*.reverse.dts

echo "Make the kernel"
#make VARIANT_DEFCONFIG=jf_$CARRIER"_defconfig" SELINUX_DEFCONFIG=jfselinux_defconfig SELINUX_LOG_DEFCONFIG=jfselinux_log_defconfig KT_jf_defconfig
make apq8084_sec_defconfig VARIANT_DEFCONFIG=apq8084_sec_trlte_ktoonsez_defconfig SELINUX_DEFCONFIG=selinux_defconfig

echo "Modding .config file - "$KTVER
sed -i 's,CONFIG_LOCALVERSION="-KT-NOTE4",CONFIG_LOCALVERSION="'$KTVER'",' .config

HOST_CHECK=`uname -n`
if [ $HOST_CHECK = 'ktoonsez-VirtualBox' ] || [ $HOST_CHECK = 'task650-Underwear' ]; then
	echo "Ktoonsez/task650 24!"
	make -j24
else
	echo "Others! - " + $HOST_CHECK
	make -j`grep 'processor' /proc/cpuinfo | wc -l`
fi;

echo "Copy modules to Package"
cp -a $(find . -name *.ko -print |grep -v initramfs) $PACKAGEDIR/system/lib/modules/
if [ $ADD_KTWEAKER = 'Y' ]; then
	cp /home/ktoonsez/workspace/com.ktoonsez.KTweaker.apk $PACKAGEDIR/system/app/com.ktoonsez.KTweaker.apk
	cp /home/ktoonsez/workspace/com.ktoonsez.KTmonitor.apk $PACKAGEDIR/system/app/com.ktoonsez.KTmonitor.apk
fi;

if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	echo "Copy zImage to Package"
	cp arch/arm/boot/zImage $PACKAGEDIR/zImage

	echo "Make boot.img"
	./mkbootfs $INITRAMFS_DEST | gzip > $PACKAGEDIR/ramdisk.gz
	tools/dtbTool -o arch/arm/boot/dt.img -s 4096 -p scripts/dtc/ arch/arm/boot/dts/
	chmod a+r arch/arm/boot/dt.img
	tools/mkbootimg --cmdline 'console=null androidboot.hardware=qcom user_debug=23 msm_rtb.filter=0x3b7 dwc3_msm.cpu_to_affin=1' --kernel $PACKAGEDIR/zImage --ramdisk $PACKAGEDIR/ramdisk.gz --base 0x00000000 --pagesize 4096 --ramdisk_offset 0x02000000 --tags_offset 0x01E00000 --dt arch/arm/boot/dt.img --output $PACKAGEDIR/boot.img 
	cd $PACKAGEDIR
	cp -R ../META-INF .

	rm ramdisk.gz
	rm zImage
	rm ../$MUXEDNAMESHRT.zip
	zip -r ../$MUXEDNAMELONG.zip .

	time_end=$(date +%s.%N)
	echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"

	export DLNAME="http://ktoonsez.jonathanjsimon.com/note4/$PLATFORM/$MUXEDNAMELONG.zip"
	
	FILENAME=../$MUXEDNAMELONG.zip
	FILESIZE=$(stat -c%s "$FILENAME")
	echo "Size of $FILENAME = $FILESIZE bytes."
	rm ../$MREV-$PLATFORM-$CARRIER"-version.txt"
	exec 1>>../$MREV-$PLATFORM-$CARRIER"-version.txt" 2>&1
	# echo -n "$MUXEDNAMELONG,$FILESIZE," & curl -s https://www.googleapis.com/urlshortener/v1/url --header 'Content-Type: application/json' --data "{'longUrl': '$DLNAME'}" | grep \"id\" | sed -e 's,^.*id": ",,' -e 's/",.*$//'
	echo -n "$MUXEDNAMELONG,$FILESIZE,$DLNAME"
	
	# SHORTURL=$(grep "http" ../$MREV-$PLATFORM-$CARRIER"-version.txt" | sed s/$MUXEDNAMELONG,$FILESIZE,//g)
	# exec 1>>../url/aurlstats-$CURDATE.sh 2>&1
	# ##echo "curl -s 'https://www.googleapis.com/urlshortener/v1/url?shortUrl="$SHORTURL"&projection=FULL' | grep -m2 \"shortUrlClicks\|\\\"longUrl\\\"\""
	# echo "echo "$MREV-$PLATFORM-$CARRIER
	# echo "curl -s 'https://www.googleapis.com/urlshortener/v1/url?shortUrl="$SHORTURL"&projection=FULL' | grep -m1 \"shortUrlClicks\""
	# #echo 1>&-
	# chmod 0777 ../url/aurlstats-$CURDATE.sh
	# sed -i 's,http://ktoonsez.jonathanjsimon.com/note4/'$PLATFORM'/'$MUXEDNAMESHRT','"[B]"$CURDATE":[/B] [url]"$SHORTURL'[/url],' ../url/SERVERLINKS.txt

	cd $KERNELDIR
else
	echo "KERNEL DID NOT BUILD! no zImage-dtb exist"
fi;
