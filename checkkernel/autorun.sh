#!/bin/bash

echo "RUNNING AX.25 TESTS"
bash /scripts/setup-ax25.sh node0
call -r udp0 node0-1
poweroff
