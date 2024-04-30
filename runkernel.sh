#!/bin/bash

fsdev_args=()
serial_arg="mon:stdio"

while getopts b:s: ch; do
	case $ch in

	# usage: -b tag:src:dst
	b)
		bindsrc=${OPTARG%:*}
		bindtag=${OPTARG#*:}
		fsdev_args+=(-fsdev "local,path=$bindsrc,id=$bindtag,security_model=none")
		fsdev_args+=(-device "virtio-9p-pci,id=$bindtag,fsdev=$bindtag,mount_tag=$bindtag")
		;;

	# usage: -s serial,args
	s)
		serial_arg=$OPTARG
		;;
	esac
done
shift $((OPTIND - 1))

exec qemu-system-x86_64 -enable-kvm -m 4g \
	-kernel ./arch/x86_64/boot/bzImage \
	-nographic -monitor none \
	-append 'console=ttyS0,115200 no_timer_check net.ifnames=0 root=root rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=5000000,cache=mmap,posixacl' \
	-fsdev "local,path=rootfs,id=root,security_model=none" \
	-device virtio-9p-pci,id=root,fsdev=root,mount_tag=root \
	-serial "${serial_arg}" \
	"${fsdev_args[@]}"
