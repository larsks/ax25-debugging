#!/bin/bash

mydir=$(readlink -f ${0%/*})

if [[ -d rootfs ]]; then
	echo "ERROR: not replacing existing rootfs" >&2
	exit 1
fi

cp -a "$mydir/rootfs.template" rootfs

podman run -i --rm -v "$mydir:/scripts" -v "$PWD/rootfs:/rootfs" alpine sh <<'EOF'

install_bin_and_deps () {
  apk add $1
  apk info -L $1 | grep bin | xargs -IBIN cp BIN /rootfs/bin/
  apk info -L $1 | grep bin | xargs -n1 ldd | awk '/=>/ {print $3}' | sort -u | xargs -ILIB cp LIB /rootfs/lib
}

mkdir -p /rootfs/dev /rootfs/tmp /rootfs/proc /rootfs/sys /rootfs/run /rootfs/bin /rootfs/lib /rootfs/usr

apk update
ln -s bin /rootfs/sbin
ln -s /bin /rootfs/usr/bin
ln -s /sbin /rootfs/usr/sbin

cp /lib/ld-musl-x86_64.so.1 /rootfs/lib
cp /bin/busybox /rootfs/bin
/bin/busybox --install -s /rootfs/bin/

install_bin_and_deps bash
install_bin_and_deps ax25-tools
install_bin_and_deps ax25-apps

tar -C /etc -cf- terminfo | tar -C /rootfs/etc -xf-

mkdir -p /rootfs/scripts
cp /scripts/setup-ax25.sh /rootfs/scripts/
EOF
