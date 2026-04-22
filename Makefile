CFLAGS_applespi.o = -I$(src)	# for tracing

CONFIG_MODULE_SIG=n
CONFIG_MODULE_SIG_ALL=n
# CONFIG_MODULE_SIG_FORCE is not set 
# CONFIG_MODULE_SIG_SHA1 is not set
# CONFIG_MODULE_SIG_SHA224 is not set
# CONFIG_MODULE_SIG_SHA256 is not set
# CONFIG_MODULE_SIG_SHA384 is not set

KVERSION := $(KERNELRELEASE)
ifeq ($(origin KERNELRELEASE), undefined)
KVERSION := $(shell uname -r)
endif

ifneq ($(KVERSION),)
	ifeq ($(shell expr $(KVERSION) \< 5.3), 1)
		obj-m += applespi.o
	endif
endif

obj-m += apple-ibridge.o
obj-m += apple-ib-tb.o
obj-m += apple-ib-als.o

KDIR := /lib/modules/$(KVERSION)/build
PWD := $(shell pwd)

MODULES := apple-ibridge.ko apple-ib-tb.ko apple-ib-als.ko
MODULES_ZST := $(MODULES:.ko=.ko.zst)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
	@for mod in $(MODULES); do \
		if [ -f "$$mod" ]; then \
			zstd -f "$$mod" -o "$$mod.zst" && rm -f "$$mod"; \
			echo "Compressing $$mod -> $$mod.zst"; \
		fi; \
	done

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f $(MODULES_ZST)

# 关键：禁用内核自带的 modules_install，手动安装 .zst 文件
install:
	# $(MAKE) -C $(KDIR) M=$(PWD) modules_install
	@sudo mkdir -p /lib/modules/$(KVERSION)/updates/apple-ibridge
	@for mod in $(MODULES_ZST); do \
		sudo install -m 644 $$mod /lib/modules/$(KVERSION)/updates/apple-ibridge/; \
		echo "Installed $$mod"; \
	done

	sudo depmod -a -w $(KVERSION)
	@echo "options apple_ib_tb idle_timeout=600" | sudo tee /etc/modprobe.d/apple-ibridge.conf > /dev/null
	@echo "options apple_ib_tb dim_timeout=300" | sudo tee -a /etc/modprobe.d/apple-ibridge.conf > /dev/null
	@echo "options apple_ib_tb fnmode=1" | sudo tee -a /etc/modprobe.d/apple-ibridge.conf > /dev/null
	@echo "Done. Config installed to /etc/modprobe.d/apple-ibridge.conf"	
	@echo -e "\n✅ 安装完成！模块路径：/lib/modules/$(KVERSION)/updates/apple-ibridge/"

test: all
	sync
    # 加载压缩的 zst 模块（现代 Linux 内核直接支持）
	-sudo rmmod apple_ib_tb 2>/dev/null
	-sudo rmmod apple_ib_als 2>/dev/null
	-sudo rmmod apple_ibridge 2>/dev/null
	sudo insmod ./apple-ibridge.ko.zst
	sudo insmod ./apple-ib-tb.ko.zst
	sudo insmod ./apple-ib-als.ko.zst
