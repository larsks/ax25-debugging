I'm trying to debug some crashes in the Linux ax.25 stack. This repository has
bits and pieces of that effort.

## Overview

When closing a socket in `ax25_release()`, we call `netdev_put()` to decrease
the refcount on the ax.25 device. However, the execution path for accepting
an incoming connection never calls `netdev_hold()`. This imbalance leads to
refcount errors, and ultimately to kernel crashes.

A typical call trace for the above situation looks like this:

    Call Trace:
    <TASK>
    ? show_regs+0x64/0x70
    ? __warn+0x83/0x120
    ? refcount_warn_saturate+0xb2/0x100
    ? report_bug+0x158/0x190
    ? prb_read_valid+0x20/0x30
    ? handle_bug+0x3e/0x70
    ? exc_invalid_op+0x1c/0x70
    ? asm_exc_invalid_op+0x1f/0x30
    ? refcount_warn_saturate+0xb2/0x100
    ? refcount_warn_saturate+0xb2/0x100
    ax25_release+0x2ad/0x360
    __sock_release+0x35/0xa0
    sock_close+0x19/0x20
    [...]

On reboot (or any attempt to remove the interface), the kernel gets
stuck in an infinite loop:

    unregister_netdevice: waiting for ax1 to become free. Usage count = 0

## Patches

- [patches-for-6.9.0](patches-for-6.9.0/) contains patches for the upstream kernel @ 6.9.0.
- [patches-for-6.6.30](patches-for-6.6.30/) contains patches for the Raspberry Pi kernel @ 6.6.30.

## Reproducing the issue

The problem is simple to reproduce and does not require any radio hardware;
instead we use [`ax25ipd`](ax25ipd) to create virtual ax.25 ports.

The [`setup-ax25.sh`](scripts/setup-ax25.sh) script will set up an appropriate
environment. On a clean system, run:

```
bash scripts/setup-ax25.sh <callsign>
```

Where `<callsign>` can be anything that looks like a valid amateur radio
callsign. I typically use `node0` (and `node1` when setting up a multi-host
environment):

```
bash scripts/setup-ax25.sh node0
```

Running this scripts will:

- Configure two ports in `/etc/ax25/axports`
- Create an `ax25ipd` configuration file for each port in `/etc/ax25/ax25ipd-<port>.conf`
- Start two `ax25ipd` instances
- Use `kissattach` to attach these instances to kernel ax.25 interfaces
- Configure `ax25d` to attach a script to `<callsign>` and `<callsign>-1`
- Start `ax25d`

[ax25ipd]: https://manpages.debian.org/unstable/ax25-apps/ax25ipd.8.en.html

After running the script, you can connect from `udp0` to `udp1` like this:

```
axcall -SRr udp0 node0-1
```

Or from `udp1` to `udp0` like this:

```
axcall -SRr udp1 node0
```

This will establish a connection and receive some sample output. When the
connection is torn down, you will see the kernel log a refcount error:

```
------------[ cut here ]------------
refcount_t: decrement hit 0; leaking memory.
*** ClearedWARNING: CPU: 1 PID: 84 at lib/refcount.c:31 refcount_warn_saturate+0x109/0x120
CPU: 1 PID: 84 Comm: axwrapper Not tainted 6.9.0-ax25-09699-geb6a9339efeb #129

Hardware name: QEMU Standard PC (i440FX + PIIX, 1996), BIOS 1.16.3-2.fc40 04/01/2014
RIP: 0010:refcount_warn_saturate+0x109/0x120
Code: ee 33 82 c6 05 f4 61 f2 00 01 e8 22 14 9d ff 0f 0b 5d c3 cc cc cc cc 48 c7 c7 08 ef 33 82 c6 05 d7 61 f2 00 01 e8 07 14 9d ff <0f> 0b 5d c3 cc cc cc cc 66 66 2e 0f 1f 84 00 00 00 00 00 0f 1f 40
RSP: 0018:ffffc900004e7d00 EFLAGS: 00010292
RAX: 000000000000002c RBX: ffff8881013d1510 RCX: 0000000000000000
RDX: 0000000000000001 RSI: ffffc900004e7b88 RDI: 00000000ffffefff
RBP: ffffc900004e7d00 R08: 00000000ffffefff R09: ffffffff824a4b88
R10: ffffffff8244cbe0 R11: ffffc900004e7ad8 R12: 0000000000000000
R13: ffffc900004e7d18 R14: ffff888100247900 R15: ffff8881013d1000
FS:  0000000000000000(0000) GS:ffff88813bd00000(0000) knlGS:0000000000000000
CS:  0010 DS: 0000 ES: 0000 CR0: 0000000080050033
CR2: 00005618f28e8040 CR3: 000000000242c000 CR4: 00000000000006b0
Call Trace:
 <TASK>
 ? show_regs.part.0+0x22/0x30
 ? show_regs.cold+0x8/0xd
 ? refcount_warn_saturate+0x109/0x120
 ? __warn.cold+0x97/0xd5
 ? refcount_warn_saturate+0x109/0x120
 ? report_bug+0x114/0x160
 ? console_unlock+0x55/0xd0
 ? handle_bug+0x42/0x80
 ? exc_invalid_op+0x1c/0x70
 ? asm_exc_invalid_op+0x1f/0x30
 ? refcount_warn_saturate+0x109/0x120
 ref_tracker_free+0x163/0x170
 ax25_release+0xfc/0x370
 sock_close+0x45/0xb0
 __fput+0x94/0x2a0
 ____fput+0x12/0x20
 task_work_run+0x61/0x90
 do_exit+0x2f5/0x9f0
 ? handle_mm_fault+0x197/0x300
 do_group_exit+0x38/0x90
 __x64_sys_exit_group+0x1c/0x20
 x64_sys_call+0x1269/0x1d00
 do_syscall_64+0x55/0x120
 entry_SYSCALL_64_after_hwframe+0x76/0x7e
RIP: 0033:0x7f743e555bce
Code: Unable to access opcode bytes at 0x7f743e555ba4.
RSP: 002b:00007fff00ad0b98 EFLAGS: 00000246 ORIG_RAX: 00000000000000e7
RAX: ffffffffffffffda RBX: 0000000000000000 RCX: 00007f743e555bce
RDX: 00007f743e555e66 RSI: 0000000000000000 RDI: 0000000000000000
RBP: 00007fff00ad0be8 R08: 0000000000000000 R09: 0000000000000000
R10: 0000000000000000 R11: 0000000000000246 R12: 00005618f28e5030
R13: 00007fff00ad0c18 R14: 0000000000000000 R15: 00007fff00ad0be0
 </TASK>
---[ end trace 0000000000000000 ]---
```

At system shutdown, you will see a second trace:

```
------------[ cut here ]------------
refcount_t: underflow; use-after-free.
WARNING: CPU: 0 PID: 70 at lib/refcount.c:28 refcount_warn_saturate+0xc6/0x120
CPU: 0 PID: 70 Comm: ax25ipd Tainted: G        W          6.9.0-ax25-09699-geb6a9339efeb #129
Hardware name: QEMU Standard PC (i440FX + PIIX, 1996), BIOS 1.16.3-2.fc40 04/01/2014
RIP: 0010:refcount_warn_saturate+0xc6/0x120
Code: 01 e8 6e 14 9d ff 0f 0b 5d c3 cc cc cc cc 80 3d 2b 62 f2 00 00 75 81 48 c7 c7 e0 ee 33 82 c6 05 1b 62 f2 00 01 e8 4a 14 9d ff <0f> 0b 5d c3 cc cc cc cc 80 3d 08 62 f2 00 00 0f 85 59 ff ff ff 48
RSP: 0018:ffffc900004a3b28 EFLAGS: 00010282
RAX: 0000000000000026 RBX: ffff888100247900 RCX: 0000000000000000
RDX: 0000000000000000 RSI: ffffc900004a39b0 RDI: 00000000ffffefff
RBP: ffffc900004a3b28 R08: 00000000ffffefff R09: ffffffff824a4b88
R10: ffffffff8244cbe0 R11: ffffc900004a3900 R12: ffff8881013d1000
R13: ffff888100247900 R14: ffff888100d0d000 R15: ffff888100d0d080
FS:  00007fadf60c6b08(0000) GS:ffff88813bc00000(0000) knlGS:0000000000000000
CS:  0010 DS: 0000 ES: 0000 CR0: 0000000080050033
CR2: 00007f79dea6b3e0 CR3: 000000000242c000 CR4: 00000000000006b0
Call Trace:
 <TASK>
 ? show_regs.part.0+0x22/0x30
 ? show_regs.cold+0x8/0xd
 ? refcount_warn_saturate+0xc6/0x120
 ? __warn.cold+0x97/0xd5
 ? refcount_warn_saturate+0xc6/0x120
 ? report_bug+0x114/0x160
 ? handle_bug+0x42/0x80
 ? exc_invalid_op+0x1c/0x70
 ? asm_exc_invalid_op+0x1f/0x30
 ? refcount_warn_saturate+0xc6/0x120
 ? refcount_warn_saturate+0xc6/0x120
 ax25_dev_device_down+0x12e/0x150
 ax25_device_event+0x1eb/0x290
 notifier_call_chain+0x40/0xc0
 raw_notifier_call_chain+0x1a/0x20
 call_netdevice_notifiers_info+0x54/0x90
 dev_close_many+0xe9/0x150
 unregister_netdevice_many_notify+0x13b/0x830
 ? __mutex_lock.constprop.0+0x3a7/0x5c0
 ? __call_rcu_common.constprop.0+0x93/0x320
 unregister_netdevice_queue+0x9a/0xe0
 unregister_netdev+0x20/0x30
 mkiss_close+0x79/0xc0
 tty_ldisc_close+0x2e/0x40
 tty_ldisc_hangup+0x104/0x220
 __tty_hangup.part.0+0x1d5/0x320
 tty_vhangup+0x19/0x30
 pty_close+0x12b/0x170
 tty_release+0x101/0x430
 __fput+0x94/0x2a0
 ____fput+0x12/0x20
 task_work_run+0x61/0x90
 do_exit+0x2f5/0x9f0
 ? handle_mm_fault+0x197/0x300
 do_group_exit+0x38/0x90
 __x64_sys_exit_group+0x1c/0x20
 x64_sys_call+0x1269/0x1d00
 do_syscall_64+0x55/0x120
 entry_SYSCALL_64_after_hwframe+0x76/0x7e
RIP: 0033:0x7fadf6041bce
Code: Unable to access opcode bytes at 0x7fadf6041ba4.
RSP: 002b:00007ffd701f8318 EFLAGS: 00000246 ORIG_RAX: 00000000000000e7
RAX: ffffffffffffffda RBX: 0000000000000001 RCX: 00007fadf6041bce
RDX: 00007fadf6041e66 RSI: 0000000000000000 RDI: 0000000000000001
RBP: 00007fadf60c6b08 R08: 0000000000000000 R09: 0000000000000000
R10: 0000000000000001 R11: 0000000000000246 R12: 00007ffd701f8828
R13: 00007ffd701f88a8 R14: 00007ffd701f88a8 R15: 00007ffd701f9130
 </TASK>
---[ end trace 0000000000000000 ]---
```

You may find that the kernel gets stuck at this point, repeating on the console messages like:

```
unregister_netdevice: waiting for ax1 to become free. Usage count = 0
```

## Automated testing

The `checkkernel.sh` script in this repository can be used to automatically test the kernel to see if it suffers from these refcount issues. This requires that you have `qemu-system-x86_64` available (for booting the kernel) and `docker` available (for building the root filesystem). **NB**: This script will overwrite your `.config` file with one designed explicitly for booting in qemu.

Check out this repository in a subdirectory of the Linux kernel, e.g.:

```
cd linux
git clone https://github.com/larsks/ax25-debugging
```

From the kernel source directory, run the `checkkernel.sh` script:

```
./ax25-debugging/checkkernel.sh
```

This will:

- Create a root filesystem tree named `rootfs` if one does not already exist
- Run `make clean`
- Copy the config from this repository into the kernel tree and run `make oldconfig`
- Build the kernel
- Boot the kernel using qemu
- Run the commands in `checkkernel/autorun.sh`
- Display a result in the terminal
- Log results to `results/<commit id>`. When the script completes, this
  directory will have the build log, the console log, and other artifacts
  generated during the test.

Output from the script looks something like this:

```
*** results and logs in results/eb6a9339ef
*** cleaning kernel (eb6a9339ef)
*** configuring kernel (eb6a9339ef)
*** building kernel using 20 cores (eb6a9339ef)
*** booting kernel (eb6a9339ef)
*** eb6a9339ef FAIL
*** all done (eb6a9339ef)
```

Because the script performs a kernel build from scratch it can take a long time to run.
