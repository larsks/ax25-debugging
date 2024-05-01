#!/bin/bash

fsdev_args=()
serial_arg="mon:stdio"
kernel_extra_args=""

while getopts b:s:a: ch; do
	case $ch in
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

	s)
		# configure default serial port
		serial_arg=$OPTARG
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
	-nographic \
	-nic user,model=virtio-net-pci \
	-append "hostname=linux console=ttyS0,115200 no_timer_check net.ifnames=0 root=root rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=5000000,cache=mmap,posixacl ${kernel_extra_args}" \
	-fsdev "local,path=rootfs,id=root,security_model=none" \
	-device virtio-9p-pci,id=root,fsdev=root,mount_tag=root \
	-smp 2 \
	"${fsdev_args[@]}" \
	-serial "${serial_arg}" \
	"$@"
