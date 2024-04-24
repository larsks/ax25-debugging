#!/bin/bash

# This script configures a test environment with two AXUDP ports named `udp0` and `udp1`, using
# callsigns `TEST-0` and `TEST-1`, respectively. Once the script completes, you can using `axcall`
# to make connections between the ports:
#
# axcall udp0 TEST-1
#
# ~or~
#
# axcall udp1 TEST-0

cat >/etc/ax25/axports <<EOF
#portname       callsign        speed   paclen  window  description
udp0 TEST-0 9600 255 2 axudp0
udp1 TEST-1 9600 255 2 axudp1
EOF

cat >/etc/ax25/ax25-udp0.conf <<EOF
socket udp 10093
mode tnc
mycall test-0
device /dev/ptmx
speed 9600
broadcast QST-0 NODES-0 FBB-0

route test-1 localhost udp 10094
EOF

cat >/etc/ax25/ax25-udp1.conf <<EOF
socket udp 10094
mode tnc
mycall test-1
device /dev/ptmx
speed 9600
broadcast QST-0 NODES-0 FBB-0

route test-0 localhost udp 10093
EOF

workdir=$(mktemp -d /tmp/ax25XXXXXX)
trap 'rm -rf $workdir' EXIT

ax25ipd -c /etc/ax25/ax25-udp0.conf >"$workdir/ax25ipd-udp0.log"
ptyudp0=$(tail -1 "$workdir/ax25ipd-udp0.log")
ax25ipd -c /etc/ax25/ax25-udp1.conf >"$workdir/ax25ipd-udp1.log"
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
