#!/bin/bash

tooldir=$(readlink -f "${0%/*}")
rootfs=${1:-rootfs}

if ! mkdir "$rootfs"; then
	echo "ERROR: will not replace existing rootfs" >&2
	exit 1
fi

docker run -i --name rootfs.$$ alpine sh <<'EOF'
apk update
apk add bash ax25-tools ax25-apps iproute2 net-tools neovim procps curl tmux
ln -s nvim /usr/bin/vim
EOF

docker container export rootfs.$$ | tar -C "$rootfs" -xf-
docker container rm -f rootfs.$$
tar -C "$tooldir/rootfs.template" -cf- . | tar -C "$rootfs" -xf-
tar -C "$tooldir/scripts" -cf- . | tar -C "$rootfs"/scripts -xf-
