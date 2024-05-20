#!/bin/bash

tooldir=$(readlink -f "${0%/*}")

docker run -i --name rootfs.$$ alpine sh >/dev/null <<'EOF'
apk update
apk add bash ax25-tools ax25-apps iproute2 net-tools neovim procps curl tmux
ln -s nvim /usr/bin/vim
EOF

fakeroot bash -s rootfs.$$ "$tooldir" <<'EOF'
rootfs=$(mktemp -d rootfsXXXXXX)
trap 'rm -rf "$rootfs"' exit

docker container export "$1" | tar -C "$rootfs" -xf-
tar -C "$2/rootfs.template" -cf- . | tar -C "$rootfs" -xf-
tar -C "$2/scripts" -cf- . | tar -C "$rootfs"/scripts -xf-

(
cd "$rootfs"
find . -print0 | cpio -0 -o -H newc
) | gzip > rootfs.cpio.gz
EOF

docker container rm -f rootfs.$$ >/dev/null
