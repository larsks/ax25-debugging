I'm trying to debug some crashes in the Linux ax.25 stack. This repository has bits and pieces of that effort.

- `config` -- a minimal(-ish) kernel configuration that I'm using to test out ax.25 on virtual machines. It has no module support -- everything is compiled in -- and includes only virtio device drivers.

- `ax25utils.py`  -- includes custom commands for `gdb`. At the time of this writing, it provides the `ax-sockets`, `ax-devs`, and `ax-notify` commands, along with some helpers that may be of more general use.

- `setup-ax25.sh` -- script to set up a test environment with a pair of AXUDP ports and some ax25d services.

- `breakpoints.gdb` -- this configures breakpoints on entry and exit for several ax25 kernel functions (and uses some of the custom commands from `ax25utils.py`).
