#!/bin/bash

set -eu

fsdev_args=()
network_args=()
net_user=1
kernel_extra_args=""
rootfs="rootfs.cpio.gz"
kernel=./arch/x86_64/boot/bzImage

while getopts r:b:a:nk: ch; do
	case $ch in
	k)
		kernel=$OPTARG
		;;
	r)
		rootfs=$OPTARG
		;;
	n)
		net_user=0
		;;
	b)
		# map a local directory to a 9p filesystem
		# usage: -b <path>:<tag>[:<security_model>]
		IFS=: read -r -a bindspec <<<"$OPTARG"
		bindsrc=${bindspec[0]}
		bindtag=${bindspec[1]}
		secmodel=${bindspec[2]:-none}
		fsdev_args+=(-fsdev "local,path=$bindsrc,id=$bindtag,security_model=${secmodel:-none}")
		fsdev_args+=(-device "virtio-9p-pci,id=$bindtag,fsdev=$bindtag,mount_tag=$bindtag")
		;;

	a)
		# append additional kernel fsdev_args
		kernel_extra_args="${kernel_extra_args:+${kernel_extra_args} }$OPTARG"
		;;

	*)
		exit 2
		;;
	esac
done
shift $((OPTIND - 1))

if ((net_user)); then
	network_args+=(-nic "user,model=virtio-net-pci")
fi

exec qemu-system-x86_64 -enable-kvm -m 4g \
	-kernel "$kernel" \
	-append "hostname=linux console=ttyS0,115200 no_timer_check net.ifnames=0 rw ${kernel_extra_args}" \
	-initrd "$rootfs" \
	-smp 2 \
	"${network_args[@]}" \
	"${fsdev_args[@]}" \
	"$@"
