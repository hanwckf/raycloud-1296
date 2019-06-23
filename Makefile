.PHONY: kernel drivers kernel-headers kernel-clean kernel-modules

include config.mk

CUR_DIR = $(shell pwd)
KDIR = linux-rt
DRIVERS_SRC = phoenix/system/src/drivers
STAGE_DIR = $(CUR_DIR)/output

CROSS_COMPILE = $(CUR_DIR)/$(CROSS_COMPILE_TOOL)
MAKE_ARCH = $(MAKE) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE)

J=$(shell grep ^processor /proc/cpuinfo | wc -l)

all:
	@echo "make { kernel | modules | kernel-modules | drivers | kernel-headers | kernel-clean | drivers-clean }"

kernel-config:
	cp -f $(KDIR)/$(KERNEL_CONFIG) $(KDIR)/.config

kernel: kernel-config
	$(MAKE_ARCH) -C $(KDIR) -j$(J) Image dtbs

modules-prepare: kernel-config
	$(MAKE_ARCH) -C $(KDIR) -j$(J) modules_prepare

kernel-modules: kernel-config modules-prepare
	mkdir -p $(STAGE_DIR)
	$(MAKE_ARCH) -C $(KDIR) -j$(J) modules
	$(MAKE_ARCH) -C $(KDIR) -j$(J) INSTALL_MOD_PATH=$(STAGE_DIR) modules_install

drivers: kernel-config modules-prepare
	$(MAKE_ARCH) -C $(DRIVERS_SRC) -j$(J)

drivers-install: drivers
	$(MAKE_ARCH) -C $(DRIVERS_SRC) install
	mkdir -p $(STAGE_DIR)/lib/modules/4.9.119-raycloud/kernel/extra
	cp -raf phoenix/system/src/bin/* $(STAGE_DIR)/lib/modules/4.9.119-raycloud/kernel/extra

drivers-clean:
	$(MAKE_ARCH) -C $(DRIVERS_SRC) clean

modules:kernel-modules drivers-install
	$(MAKE_ARCH) -C $(KDIR) -j$(J) INSTALL_MOD_PATH=$(STAGE_DIR) _depmod

kernel-headers: kernel-config
	$(MAKE_ARCH) -C $(KDIR) -j$(J) INSTALL_HDR_PATH=$(STAGE_DIR) headers_install

kernel-clean: kernel-config
	$(MAKE_ARCH) -C $(KDIR) clean
