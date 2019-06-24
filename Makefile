.PHONY: kernel modules drivers kernel-clean kernel-modules drivers-clean

include config.mk

KDIR = linux-rt
KVER = 4.9.119-raycloud
DRIVERS_SRC = phoenix/system/src

CUR_DIR = $(shell pwd)
STAGE_DIR = $(CUR_DIR)/stage
OUTPUT_DIR = $(CUR_DIR)/output

CROSS_COMPILE = $(CUR_DIR)/$(CROSS_COMPILE_TOOL)
MAKE_ARCH = $(MAKE) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE)

J=$(shell grep ^processor /proc/cpuinfo | wc -l)

help:
	@echo "make { all | kernel | modules | kernel-modules | drivers | kernel-clean | drivers-clean }"

all: kernel modules
	mkdir -p $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/Image $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/dts/realtek/rtd129x/$(DTB) $(OUTPUT_DIR)
	tar cf $(OUTPUT_DIR)/modules.tar -C $(STAGE_DIR) lib
	xz -f -T0 $(OUTPUT_DIR)/modules.tar

kernel-config:
	cp -f $(KDIR)/$(KERNEL_CONFIG) $(KDIR)/.config

kernel: kernel-config
	$(MAKE_ARCH) -C $(KDIR) -j$(J) Image dtbs

modules-prepare: kernel-config
	$(MAKE_ARCH) -C $(KDIR) -j$(J) modules_prepare

kernel-modules: kernel-config modules-prepare
	mkdir -p $(STAGE_DIR)
	rm -rf $(STAGE_DIR)/lib
	$(MAKE_ARCH) -C $(KDIR) -j$(J) modules
	$(MAKE_ARCH) -C $(KDIR) -j$(J) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(STAGE_DIR) modules_install

drivers: kernel-config modules-prepare
	$(MAKE_ARCH) -C $(DRIVERS_SRC)/drivers -j$(J)

drivers-install: drivers
	$(MAKE_ARCH) -C $(DRIVERS_SRC)/drivers install
	mkdir -p $(STAGE_DIR)/lib/modules/$(KVER)/kernel/extra
	cp -raf phoenix/system/src/bin/* $(STAGE_DIR)/lib/modules/4.9.119-raycloud/kernel/extra

drivers-clean:
	$(MAKE_ARCH) -C $(DRIVERS_SRC)/drivers clean
	rm -rf $(DRIVERS_SRC)/bin

modules:kernel-modules drivers-install
	$(MAKE_ARCH) -C $(KDIR) -j$(J) INSTALL_MOD_PATH=$(STAGE_DIR) _depmod
	rm -f $(STAGE_DIR)/lib/modules/$(KVER)/build $(STAGE_DIR)/lib/modules/$(KVER)/source

kernel-clean: kernel-config
	$(MAKE_ARCH) -C $(KDIR) clean

clean: kernel-clean drivers-clean
	rm -rf $(STAGE_DIR)
	rm -f $(OUTPUT_DIR)/*
