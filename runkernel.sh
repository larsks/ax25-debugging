#!/bin/bash

fsdev_args=()
qemu_args=()
serial_arg="mon:stdio"
kernel_extra_args=""

while getopts b:s:g:w ch; do
	case $ch in

	# map a local directory to a 9p filesystem
	# usage: -b tag:src:dst
	b)
		bindsrc=${OPTARG%:*}
		bindtag=${OPTARG#*:}
		fsdev_args+=(-fsdev "local,path=$bindsrc,id=$bindtag,security_model=none")
		fsdev_args+=(-device "virtio-9p-pci,id=$bindtag,fsdev=$bindtag,mount_tag=$bindtag")
		;;

  # configure default serial port
  # usage: -s serial_arg
	s)
		serial_arg=$OPTARG
		;;

  # enable serial port for kgdb
  # usage: -g <port>
	g)
		qemu_args+=(-serial "tcp::$OPTARG,server,nowait")
		kernel_extra_args="${kernel_extra_args:+${kernel_extra_args} }kgdboc=ttyS1,115200"
		;;

  # enable kgdbwait
  # usage: -w
  w)
		kernel_extra_args="${kernel_extra_args:+${kernel_extra_args} }kgdbwait"
		;;

	*)
		exit 2
		;;
	esac
done
shift $((OPTIND - 1))

exec qemu-system-x86_64 -enable-kvm -m 4g \
	-kernel ./arch/x86_64/boot/bzImage \
	-nographic \
	-nic user,model=virtio-net-pci \
	-append "console=ttyS0,115200 no_timer_check net.ifnames=0 root=root rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=5000000,cache=mmap,posixacl ${kernel_extra_args}" \
	-fsdev "local,path=rootfs,id=root,security_model=none" \
	-device virtio-9p-pci,id=root,fsdev=root,mount_tag=root \
	"${fsdev_args[@]}" \
	-serial "${serial_arg}" \
	"${qemu_args[@]}" \
	"$@"
