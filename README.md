I'm trying to debug some crashes in the Linux ax.25 stack. This repository has bits and pieces of that effort.

- `config` -- a minimal(-ish) kernel configuration that I'm using to test out ax.25 on virtual machines. It has no module support -- everything is compiled in -- and includes only virtio device drivers.

- `ax25utils.py`  -- includes custom commands for `gdb`. At the time of this writing, it provides the `ax-sockets` commands, which iterates over the `ax25_list` variable and displays some information from the `ax25_cb` values in that list:

  ```
  (gdb) ax-sockets
  0xffff888103b5b200 LISTEN       ax0 src:N1LKS-4    dst:<none>     cb:02 dev:01
  0xffff888103b5b000 LISTEN       ax1 src:N1LKS-3    dst:<none>     cb:02 dev:02
  ```

  The last two fields (`cb:` and `dev:`) show the refcounts for the `ax25_cb` and `ax25_cb->ax25_dev`.

- `setup-ax25.sh` -- script to set up a test environment with a pair of AXUDP ports and some ax25d services.

- `breakpoints.gdb` -- this configures breakpoints on entry and exit for several ax25 kernel functions.
