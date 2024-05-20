import sys
import gdb
import gdb.printing

ax25_cb_type = gdb.lookup_type("struct ax25_cb")
ax25_dev_type = gdb.lookup_type("struct ax25_dev")
netdev_notifier_info_type = gdb.lookup_type("struct netdev_notifier_info")

ax25_state = ["LISTEN", "SABM_SENT", "DISC_SENT", "ESTABLISHED", "RECOVERY"]
netdev_events = [
    "<none>",
    "NETDEV_UP",
    "NETDEV_DOWN",
    "NETDEV_REBOOT",
    "NETDEV_CHANGE",
    "NETDEV_REGISTER",
    "NETDEV_UNREGISTER",
    "NETDEV_CHANGEMTU",
    "NETDEV_CHANGEADDR",
    "NETDEV_PRE_CHANGEADDR",
    "NETDEV_GOING_DOWN",
    "NETDEV_CHANGENAME",
    "NETDEV_FEAT_CHANGE",
    "NETDEV_BONDING_FAILOVER",
    "NETDEV_PRE_UP",
    "NETDEV_PRE_TYPE_CHANGE",
    "NETDEV_POST_TYPE_CHANGE",
    "NETDEV_POST_INIT",
    "NETDEV_PRE_UNINIT",
    "NETDEV_RELEASE",
    "NETDEV_NOTIFY_PEERS",
    "NETDEV_JOIN",
    "NETDEV_CHANGEUPPER",
    "NETDEV_RESEND_IGMP",
    "NETDEV_PRECHANGEMTU",
    "NETDEV_CHANGEINFODATA",
    "NETDEV_BONDING_INFO",
    "NETDEV_PRECHANGEUPPER",
    "NETDEV_CHANGELOWERSTATE",
    "NETDEV_UDP_TUNNEL_PUSH_INFO",
    "NETDEV_UDP_TUNNEL_DROP_INFO",
    "NETDEV_CHANGE_TX_QUEUE_LEN",
    "NETDEV_CVLAN_FILTER_PUSH_INFO",
    "NETDEV_CVLAN_FILTER_DROP_INFO",
    "NETDEV_SVLAN_FILTER_PUSH_INFO",
    "NETDEV_SVLAN_FILTER_DROP_INFO",
    "NETDEV_OFFLOAD_XSTATS_ENABLE",
    "NETDEV_OFFLOAD_XSTATS_DISABLE",
    "NETDEV_OFFLOAD_XSTATS_REPORT_USED",
    "NETDEV_OFFLOAD_XSTATS_REPORT_DELTA",
    "NETDEV_XDP_FEAT_CHANGE",
]

ax25_values = [
    "AX25_VALUES_IPDEFMODE",
    "AX25_VALUES_AXDEFMODE",
    "AX25_VALUES_BACKOFF",
    "AX25_VALUES_CONMODE",
    "AX25_VALUES_WINDOW",
    "AX25_VALUES_EWINDOW",
    "AX25_VALUES_T1",
    "AX25_VALUES_T2",
    "AX25_VALUES_T3",
    "AX25_VALUES_IDLE",
    "AX25_VALUES_N2",
    "AX25_VALUES_PACLEN",
    "AX25_VALUES_PROTOCOL",
    "AX25_VALUES_DS_TIMEOUT",
]

printer = gdb.printing.RegexpCollectionPrettyPrinter("ax25")


class FinishBreakpoint(gdb.FinishBreakpoint):
    def __init__(self, commands):
        super().__init__()
        self.finish_commands = commands

    def stop(self):
        for command in self.finish_commands:
            gdb.execute(command)
        return False


def netdev_event_name(event):
    return netdev_events[event]


def ax_dev_from_notify():
    event = gdb.parse_and_eval("event")
    event_name = netdev_events[event]

    ptr = gdb.parse_and_eval("ptr")
    ndi = ptr.cast(netdev_notifier_info_type.pointer())
    dev = ndi.referenced_value()["dev"]
    name = dev["name"].string()

    return {"name": name, "event": event_name, "dev": dev}


def ax2asc(val):
    """Make a callsign readable"""
    callsign_chars = []

    if val[0] == 0:
        return "<none>"

    for i in range(6):
        if val[i] == 0:
            callsign_chars.append("_")
        else:
            callsign_chars.append(chr((val[i] >> 1) & 0x7F))

    callsign = "".join(callsign_chars)
    ssid = (val[6] >> 1) & 0x0F

    return f"{callsign.strip()}-{ssid}"


def ax25_list_devs():
    """List elements of ax25_dev_list"""
    ax25_dev_ptr_type = ax25_dev_type.pointer()
    ax25_dev_list = gdb.parse_and_eval("ax25_dev_list")
    axdev = ax25_dev_list["next"]
    while axdev != ax25_dev_list.address:
        yield axdev.cast(ax25_dev_ptr_type)
        axdev = axdev["next"]


def ax25_list_sockets():
    """List elements of ax25_list"""
    ax25_cb_ptr_type = ax25_cb_type.pointer()
    ax25_list = gdb.parse_and_eval("ax25_list").address
    axsock = ax25_list["first"]
    while axsock:
        yield axsock.cast(ax25_cb_ptr_type)
        axsock = axsock["next"]


def gdbprinter(name, regexp):
    """Dectorator for turning a Python function into a gdb pretty printer"""

    def outside(func):
        class PrettyPrinter(gdb.ValuePrinter):
            def __init__(self, val):
                self.__val = val

            def to_string(self):
                return func(self.__val)

        printer.add_printer(name, regexp, PrettyPrinter)

    return outside


def gdbfunction(name):
    """Decorator for turning a Python function into a gdb convenience function."""

    def outside(func):
        class Function(gdb.Function):
            def __init__(self):
                super().__init__(name)

            def invoke(self, arg):
                return func(arg)

        Function.__doc__ = func.__doc__
        Function()

    return outside


def gdbcommand(name, command_class=gdb.COMMAND_USER):
    """Decorator for turning a Python function into a gdb command."""

    def outside(func):
        class Command(gdb.Command):
            def __init__(self):
                super().__init__(name, command_class)

            def invoke(self, arg, from_tty):
                return func(arg, from_tty)

        Command.__doc__ = func.__doc__
        Command()

    return outside


@gdbcommand("ax-devs")
def cmd_ax_devs(arg, from_tty):
    """Show members of ax25_dev_list"""
    for axdev in ax25_list_devs():
        gdb.write(
            f"{axdev['dev']['name'].string()} "
            f"axrefcnt:{int(axdev['refcount']['refs']['counter']):02} "
            f"devrefcnt:{int(axdev['dev']['dev_refcnt']['refs']['counter']):02} "
            f"untracked:{int(axdev['dev']['refcnt_tracker']['untracked']['refs']['counter']):02} "
            f"notrack:{int(axdev['dev']['refcnt_tracker']['no_tracker']['refs']['counter']):02} "
            "\n"
        )


@gdbcommand("ax-sockets")
def cmd_ax_sockets(arg, from_tty):
    """Show members of ax25_list"""
    for axsock in ax25_list_sockets():
        gdb.write(
            f"{axsock.format_string()} "
            f"{ax25_state[axsock['state']]:12} "
            f"{axsock['ax25_dev']['dev']['name'].string()} "
            f"src:{ax2asc(axsock['source_addr']['ax25_call']):10} dst:{ax2asc(axsock['dest_addr']['ax25_call']):10} "
            f"cb:{int(axsock['refcount']['refs']['counter']):02} "
            f"dev:{int(axsock['ax25_dev']['refcount']['refs']['counter']):02} "
            f"tracker:{axsock['dev_tracker'].format_string()} "
            "\n"
        )


@gdbcommand("ax-notify")
def cmd_ax_notify(arg, from_tty):
    """Show information about a device notifiy event"""
    info = ax_dev_from_notify()
    gdb.write(f"dev:{info['name']} event:{info['event']}\n")


# via https://sourceware.org/legacy-ml/gdb/2010-06/msg00100.html
@gdbcommand("ignore-errors")
def ignore_errors(arg, from_tty):
    """Execute a single command, ignoring all errors."""
    try:
        gdb.execute(arg, from_tty)
    except Exception:
        pass


@gdbfunction("is_optimized_out")
def is_optimized_out(arg):
    val = gdb.parse_and_eval(arg.string())
    return val.is_optimized_out


@gdbprinter("ax25_cb", "^ax25_cb$")
def ax25_cb_printer(val):
    return (
        "AX25_CB: "
        f"state:{ax25_state[val['state']]} "
        f"dev:{val['ax25_dev']['dev']['name'].string()} "
        f"src:{ax2asc(val['source_addr']['ax25_call'])} dst:{ax2asc(val['dest_addr']['ax25_call'])} "
        f"refcount:{int(val['refcount']['refs']['counter'])} "
        f"dev_tracker:{val['dev_tracker'].format_string()} "
        "\n"
    )


@gdbprinter("refcount_t", "^refcount_struct$")
def refcount_t_printer(val):
    return f"<{val["refs"]["counter"]}>"


@gdbprinter("refcnt_tracker", "^ref_tracker_dir")
def ref_tracker_printer(val):
    return f"<untracked:{val['untracked'].format_string()} no_tracker:{val['no_tracker'].format_string()}"


@gdbcommand("prefix-output")
def prefix_output(arg, from_tty):
    prefix, arg = arg.split(None, 1)
    res = gdb.execute(arg, from_tty, True)
    for line in res.splitlines():
        gdb.write(f"{prefix} {line}\n")


def register_pretty_printer():
    gdb.printing.register_pretty_printer(gdb.current_objfile(), printer)
