define show_ax_sockets
echo === $arg0 ===\n
ax-sockets
py FinishBreakpoint(["ax-sockets"])
end

# Display the contents of ax25_list before and after certain functions
break ax25_cb_add
commands
silent
show_ax_sockets ax25_cb_add
continue
end

break ax25_release
commands
silent
show_ax_sockets ax25_release
continue
end

break ax25_cb_del
commands
silent
show_ax_sockets ax25_cb_del
continue
end

break ax25_accept
commands
silent
show_ax_sockets ax25_accept
continue
end

break ax25_bind
commands
silent
show_ax_sockets ax25_bind
continue
end

#break ax25_device_event if ((struct netdev_notifier_info *)ptr)->dev->type == 3
#commands
#silent
#ax-notify
#end
