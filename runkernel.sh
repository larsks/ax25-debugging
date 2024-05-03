#!/bin/bash

set -eu

fsdev_args=()
network_args=()
net_user=1
kernel_extra_args=""
rootfs="rootfs"

while getopts r:b:a:n ch; do
	case $ch in
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

cat <<EOF
===========================================================================

             ▄▄         ▄▄▄▄▄▄   ▄▄▄   ▄▄  ▄▄    ▄▄  ▄▄▄  ▄▄▄ 
             ██         ▀▀██▀▀   ███   ██  ██    ██   ██▄▄██  
             ██           ██     ██▀█  ██  ██    ██    ████   
             ██           ██     ██ ██ ██  ██    ██     ██    
             ██           ██     ██  █▄██  ██    ██    ████   
             ██▄▄▄▄▄▄   ▄▄██▄▄   ██   ███  ▀██▄▄██▀   ██  ██  
             ▀▀▀▀▀▀▀▀   ▀▀▀▀▀▀   ▀▀   ▀▀▀    ▀▀▀▀    ▀▀▀  ▀▀▀ 

===========================================================================
EOF

exec qemu-system-x86_64 -enable-kvm -m 4g \
	-kernel ./arch/x86_64/boot/bzImage \
	-append "hostname=linux console=ttyS0,115200 no_timer_check net.ifnames=0 root=root rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=5000000,cache=mmap,posixacl ${kernel_extra_args}" \
	-fsdev "local,path=$rootfs,id=root,security_model=none" \
	-device virtio-9p-pci,id=root,fsdev=root,mount_tag=root \
	-smp 2 \
	"${network_args[@]}" \
	"${fsdev_args[@]}" \
	"$@"
