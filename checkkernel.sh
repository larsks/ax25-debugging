#!/bin/bash

unset KCONFIG
tooldir=$(readlink -f "${0%/*}")

if ! [[ -f rootfs.cpio.gz ]]; then
	echo "*** no rootfs -- creating root filesystem"
	"$tooldir/make-rootfs.sh"
fi

rev=$(git rev-parse --short=10 HEAD)
result_dir="results/$rev"
mkdir -p "$result_dir"
console_log="$result_dir/console.log"

echo "*** results and logs in $result_dir"
echo "*** cleaning kernel ($rev)"
make clean >"$result_dir/clean.log"

echo "*** configuring kernel ($rev)"
cp "$tooldir/config" .config
yes "" | make oldconfig >"$result_dir/config.log" || exit 125
cp .config "$result_dir/config"

nproc="$(nproc)"
echo "*** building kernel using $nproc cores ($rev)"
make "-j$nproc" >"$result_dir/build.log" || exit 125

echo "*** booting kernel ($rev)"
timeout --foreground 30 bash "$tooldir/runkernel.sh" \
	-b "$tooldir/checkkernel:checkkernel" -- -nographic -serial "file:$console_log" -monitor none

if ! grep -q "RUNNING AX.25 TESTS" "$console_log"; then
	echo "*** $rev DID NOT RUN TESTS"
	res=2
elif grep -qE 'waiting for.*to become free|cut here' "$console_log"; then
	echo "*** $rev FAIL"
	res=1
else
	echo "*** $rev OKAY"
	res=0
fi

echo $res >"$result_dir/result"

echo "*** all done ($rev)"
exit $res
