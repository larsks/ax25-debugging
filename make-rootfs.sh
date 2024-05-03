#!/bin/bash

mydir=$(readlink -f ${0%/*})
rootfs=${1:-rootfs}

if ! mkdir "$rootfs"; then
	echo "ERROR: will not replace existing rootfs" >&2
	exit 1
fi

podman run -i --name rootfs.$$ alpine sh <<'EOF'
apk update
apk add bash ax25-tools ax25-apps iproute2 net-tools neovim procps curl tmux
ln -s nvim /usr/bin/vim
EOF

podman export rootfs.$$ | tar -C "$rootfs" -xf-
tar -C "$mydir/rootfs.template" -cf- . | tar -C "$rootfs" -xf-
tar -C "$mydir/scripts" -cf- . | tar -C "$rootfs"/scripts -xf-
