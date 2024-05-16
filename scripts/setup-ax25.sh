#!/bin/bash
#
# usage: setup-ax25.sh <callsign> [<ax25ipd_route> [...]]
#
# On a single system, you could run:
#
#     bash setup-ax25.sh node0
#
# This gets you two ax.25 ports, one for callsign `node0` and one
# for callsign `node0-1`. You can then connect from one to the other:
#
#     axcall -r udp0 node0-1
#     axcall -r udp1 node0
#
# If you want to use multiple hosts, you can run on one:
#
#     bash setup-ax25.sh node0 'node1 node1 udp 10093 bd'
#
# And on the other:
#
#     bash setup-ax25.sh node1 'node0 node0 udp 10093 bd'
#
# This assumes that you have two systems, `node0` and `node1`, and
# that the hostnames resolve correctly. Once configured, you can connect
# from node0 to node1 like this:
#
#     axcall -r udp0 node1


CALLSIGN=$1
shift

if [[ -z $CALLSIGN ]]; then
	echo "$0: usage: ${0##*/} callsign" >&2
	exit 1
fi

cat >/etc/ax25/axports <<EOF
#portname       callsign        speed   paclen  window  description
udp0 ${CALLSIGN}-0 9600 255 2 axudp0
udp1 ${CALLSIGN}-1 9600 255 2 axudp1
EOF

cat >/etc/ax25/ax25ipd-udp0.conf <<EOF
socket udp 10093
mode tnc
mycall ${CALLSIGN}-0
device /dev/ptmx
speed 9600
broadcast QST-0 NODES-0 FBB-0

route ${CALLSIGN}-1 localhost udp 10094
$(
	for route in "$@"; do
		echo "route $route"
	done
)
EOF

cat >/etc/ax25/ax25ipd-udp1.conf <<EOF
socket udp 10094
mode tnc
mycall ${CALLSIGN}-1
device /dev/ptmx
speed 9600
broadcast QST-0 NODES-0 FBB-0

route ${CALLSIGN}-0 localhost udp 10093 d
EOF

workdir=$(mktemp -d /tmp/ax25XXXXXX)
trap 'rm -rf $workdir' EXIT

ax25ipd -c /etc/ax25/ax25ipd-udp0.conf >"$workdir/ax25ipd-udp0.log"
ptyudp0=$(tail -1 "$workdir/ax25ipd-udp0.log")
ax25ipd -c /etc/ax25/ax25ipd-udp1.conf >"$workdir/ax25ipd-udp1.log"
ptyudp1=$(tail -1 "$workdir/ax25ipd-udp1.log")

while ! [[ -c "$ptyudp0" ]]; do sleep 0.2; done
while ! [[ -c "$ptyudp1" ]]; do sleep 0.2; done

kissattach "$ptyudp0" udp0
kissparms -p udp0 -c 1
kissattach "$ptyudp1" udp1
kissparms -p udp1 -c 1

cat >/etc/ax25/example-output.sh <<EOF
#!/bin/sh

echo This is a test.
sleep 0.5
echo This is only a test.
sleep 0.5
EOF

cat >/etc/ax25/ax25d.conf <<EOF
[udp0]
NOCALL   * * * * * *  L
default  * * * * * *  - root  /usr/sbin/axwrapper axwrapper -- /bin/sh sh /etc/ax25/example-output.sh

[udp1]
NOCALL   * * * * * *  L
default  * * * * * *  - root  /usr/sbin/axwrapper axwrapper -- /bin/sh sh /etc/ax25/example-output.sh
EOF

ax25d -l
