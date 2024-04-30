#!/bin/bash

qemu_args=()
fsid=1

while getopts b: ch; do
	case $ch in
	b)
		bindsrc=${OPTARG%:*}
		bindtgt=${OPTARG#*:}
		bindtag=fs$((fsid++))
		qemu_args+=(-fsdev "local,path=$bindsrc,id=$bindtag,security_model=none")
		qemu_args+=(-device virtio-9p-pci,id=$bindtag,fsdev=$bindtag,mount_tag=$bindtag)
		;;
	esac
done
shift $((OPTIND - 1))

exec qemu-system-x86_64 -enable-kvm -m 4g \
	-kernel ./arch/x86_64/boot/bzImage \
	-nographic -monitor none -serial mon:stdio \
	-append 'console=ttyS0,115200 no_timer_check net.ifnames=0 root=fs0 rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=5000000,cache=mmap,posixacl' \
	-fsdev "local,path=rootfs,id=fs0,security_model=none" \
	-device virtio-9p-pci,id=fs0,fsdev=fs0,mount_tag=fs0 \
	"${qemu_args[@]}"
