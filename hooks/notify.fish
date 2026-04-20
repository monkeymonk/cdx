# cdx hook: notify — send desktop notification on enter

function cdx_hook_notify --argument-names mode dir
    test "$mode" = enter; or return 0  # enter only — notification not useful in inspect mode
    type -q notify-send; or return 0
    notify-send "cdx" "Entered: $dir" --expire-time=2000 >/dev/null 2>&1
end

cdx_register_hook async cdx_hook_notify
