#Android makefile to build kernel as a part of Android Build
PERL		= perl

# Adding SS specific Kconfig
ifeq ( ,$(findstring VARIANT_DEFCONFIG, $(KERNEL_DEFCONFIG)))
KERNEL_DEFCONFIG += VARIANT_DEFCONFIG=$(VARIANT_DEFCONFIG) DEBUG_DEFCONFIG=$(DEBUG_DEFCONFIG) SELINUX_DEFCONFIG=$(SELINUX_DEFCONFIG) SELINUX_LOG_DEFCONFIG=$(SELINUX_LOG_DEFCONFIG) TIMA_DEFCONFIG=$(TIMA_DEFCONFIG) DMVERITY_DEFCONFIG=$(DMVERITY_DEFCONFIG)
endif

TARGET_KERNEL_ARCH := $(strip $(TARGET_KERNEL_ARCH))
ifeq ($(TARGET_KERNEL_ARCH),)
KERNEL_ARCH := arm
else
KERNEL_ARCH := $(TARGET_KERNEL_ARCH)
endif

TARGET_KERNEL_HEADER_ARCH := $(strip $(TARGET_KERNEL_HEADER_ARCH))
ifeq ($(TARGET_KERNEL_HEADER_ARCH),)
KERNEL_HEADER_ARCH := $(KERNEL_ARCH)
else
$(warning Forcing kernel header generation only for '$(TARGET_KERNEL_HEADER_ARCH)')
KERNEL_HEADER_ARCH := $(TARGET_KERNEL_HEADER_ARCH)
endif

KERNEL_HEADER_DEFCONFIG := $(strip $(KERNEL_HEADER_DEFCONFIG))
ifeq ($(KERNEL_HEADER_DEFCONFIG),)
KERNEL_HEADER_DEFCONFIG := $(KERNEL_DEFCONFIG)
endif

TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(strip $(TARGET_KERNEL_CROSS_COMPILE_PREFIX))
ifeq ($(TARGET_KERNEL_CROSS_COMPILE_PREFIX),)
KERNEL_CROSS_COMPILE := arm-eabi-
else
KERNEL_CROSS_COMPILE := $(TARGET_KERNEL_CROSS_COMPILE_PREFIX)
endif

ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/Image
else
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/zImage
endif

ifeq ($(TARGET_KERNEL_APPEND_DTB), true)
$(info Using appended DTB)
TARGET_PREBUILT_INT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)-dtb
endif

KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules

TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)

define mv-modules
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`;\
ko=`find $$mpath/kernel -type f -name *.ko`;\
for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
fi
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`; rm -rf $$mpath;\
fi
endef

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) SELINUX_DEFCONFIG=$(SELINUX_DEFCONFIG) SELINUX_LOG_DEFCONFIG=$(SELINUX_LOG_DEFCONFIG) TIMA_DEFCONFIG=$(TIMA_DEFCONFIG) $(KERNEL_DEFCONFIG) DMVERITY_DEFCONFIG=$(DMVERITY_DEFCONFIG)

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_HEADERS_INSTALL)
	$(hide) rm -rf $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/dts
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) modules
	$(MAKE) -C kernel O=../$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) INSTALL_MOD_STRIP=1 ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) modules_install
	$(mv-modules)
	$(clean-module-folder)

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT)
	$(hide) rm -f ../$(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_HEADER_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_HEADER_DEFCONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_HEADER_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) headers_install
	$(hide) rm -f ../$(KERNEL_CONFIG)
ifeq ($(SEC_FACTORY_BUILD),true)
	echo -e "\nCONFIG_SEC_FACTORY=y" >>kernel/arch/arm/configs/$(KERNEL_DEFCONFIG)
endif
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_DEFCONFIG)

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) savedefconfig
	cp $(KERNEL_OUT)/defconfig kernel/arch/$(KERNEL_ARCH)/configs/$(KERNEL_DEFCONFIG)

endif
