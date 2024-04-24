# Display the contents of ax25_list before and after certain functions
break ax25_cb_add
commands
silent
echo === ax25_cb_add ===\n
ax-sockets
py FinishBreakpoint(["ax-sockets"])
continue
end

break ax25_release
commands
silent
echo === ax25_release ===\n
ax-sockets
py FinishBreakpoint(["ax-sockets"])
continue
end

break ax25_cb_del
commands
silent
echo === ax25_release ===\n
ax-sockets
py FinishBreakpoint(["ax-sockets"])
continue
end
