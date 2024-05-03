define show_ax_info
echo === $arg0 ===\n
prefix-output $arg0 echo ENTER:\n
prefix-output $arg0 ax-devs
prefix-output $arg0 ax-sockets
py FinishBreakpoint([r"prefix-output $arg0 echo EXIT:\n", "prefix-output $arg0 ax-sockets", "prefix-output $arg0 ax-devs"])
end

# Display the contents of ax25_list before and after certain functions
break ax25_cb_add
commands
silent
show_ax_info ax25_cb_add
continue
end

break ax25_release
commands
silent
show_ax_info ax25_release
continue
end

break ax25_cb_del
commands
silent
show_ax_info ax25_cb_del
continue
end

break ax25_accept
commands
silent
show_ax_info ax25_accept
continue
end

break ax25_bind
commands
silent
show_ax_info ax25_bind
continue
end

break ax25_rcv
commands
silent
show_ax_info ax25_rcv
continue
end

#break ax25_device_event if ((struct netdev_notifier_info *)ptr)->dev->type == 3
#commands
#silent
#ax-notify
#end
