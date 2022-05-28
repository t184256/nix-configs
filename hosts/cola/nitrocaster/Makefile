obj-m += i965.o

all:
	make -C $(KERNEL_DIR) M=$(PWD) modules

install:
	make -C $(KERNEL_DIR) M=$(PWD) modules_install
