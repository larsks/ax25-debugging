import sys
import gdb

sys.path.append("scripts/gdb")
from linux import lists, utils

ax25_cb_type = utils.CachedType("struct ax25_cb")
ax25_state = ["LISTEN", "SABM_SENT", "DISC_SENT", "ESTABLISHED", "RECOVERY"]


class FinishBreakpoint(gdb.FinishBreakpoint):
    def __init__(self, commands):
        super().__init__()
        self.finish_commands = commands

    def stop(self):
        for command in self.finish_commands:
            gdb.execute(command)
        return False


def ax2asc(val):
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


def ax25_list_sockets():
    ax25_cb_ptr_type = ax25_cb_type.get_type().pointer()
    ax25_list = gdb.parse_and_eval("ax25_list").address
    for axsock in lists.hlist_for_each_entry(ax25_list, ax25_cb_ptr_type, "ax25_node"):
        yield axsock


class AxSockets(gdb.Command):
    def __init__(self):
        super().__init__("ax-sockets", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        for axsock in ax25_list_sockets():
            gdb.write(
                f"{axsock.format_string()} "
                f"{ax25_state[axsock['state']]:12} "
                f"{axsock['ax25_dev']['dev']['name'].string()} "
                f"src:{ax2asc(axsock['source_addr']['ax25_call']):10} dst:{ax2asc(axsock['dest_addr']['ax25_call']):10} "
                f"cb:{int(axsock['refcount']['refs']['counter']):02} "
                f"dev:{int(axsock['ax25_dev']['refcount']['refs']['counter']):02} "
                "\n"
            )


AxSockets()
