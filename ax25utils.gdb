define ax-devs
  set $x = ax25_dev_list
  while ($x != 0)
    printf "%s paclen:%d window:%d ax_refcnt:%d dev_refcnt:%d dev_untracked:%d dev_notrack:%d\n", $x->dev->name, \
      $x->values[AX25_VALUES_PACLEN], \
      $x->values[AX25_VALUES_WINDOW], \
      $x->refcount->refs->counter, \
      $x->dev->dev_refcnt->refs->counter, \
      $x->dev->refcnt_tracker->untracked->refs->counter, \
      $x->dev->refcnt_tracker->no_tracker->refs->counter
    set $x = $x->next
  end
end

define ax-sockets
  set $x = ax25_list->first
  while ($x != 0)
    set $cb = (ax25_cb *)($x)

    if ($cb->state == 0)
      set $state = "LISTEN"
    end
    if ($cb->state == 1)
      set $state = "SABM_SENT"
    end
    if ($cb->state == 2)
      set $state = "DISC_SENT"
    end
    if ($cb->state == 3)
      set $state = "ESTABLISHED"
    end
    if ($cb->state == 4)
      set $state = "RECOVERY"
    end
    if ($cb->state > 4)
      set $state = "UNKNOWN"
    end

    printf "%s if:%s state:%s paclen:%d window:%d refcnt:%d\n", \
      $_as_string($cb), \
      $cb->ax25_dev->dev->name, \
      $state, \
      $cb->paclen, \
      $cb->window, \
      $cb->refcount->refs->counter
    set $x = $x->next
  end
end
