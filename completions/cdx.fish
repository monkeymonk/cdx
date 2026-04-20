# cdx fish completion

function __cdx_up_prefix --argument-names num
    set -l prefix ""
    for i in (seq $num)
        set prefix "../$prefix"
    end
    echo $prefix
end

function __cdx_shorthand_dirs --argument-names num rest display_prefix
    set -l up_prefix (__cdx_up_prefix $num)
    set -l pattern "$up_prefix$rest"'*/'
    for d in (eval "printf '%s\n' $pattern")
        test -d $d; or continue
        set -l clean (string replace -- $up_prefix '' $d)
        echo "$display_prefix$num/$clean"
    end
end

function __cdx_complete
    set -l cur (commandline -ct)
    set -l tokens (commandline -pco)
    set -l prev ""
    if test (count $tokens) -gt 0
        set prev $tokens[-1]
    end

    # `-N/subpath` or `-N` shorthand
    if string match -rq '^-[0-9]' -- $cur
        if string match -rq '^-[0-9]+/' -- $cur
            set -l num (string replace -r '^-([0-9]+)/.*' '$1' -- $cur)
            set -l rest (string replace -r '^-[0-9]+/' '' -- $cur)
            __cdx_shorthand_dirs $num $rest '-'
            return
        end
        if string match -rq '^-[0-9]+$' -- $cur
            set -l num (string sub -s 2 -- $cur)
            __cdx_shorthand_dirs $num '' '-'
            return
        end
        # Partial like `-` — offer -1..-9
        for n in (seq 1 9)
            echo -$n
        end
        return
    end

    # After --up
    if test "$prev" = "--up"
        if string match -rq '^[0-9]+/' -- $cur
            set -l num (string replace -r '^([0-9]+)/.*' '$1' -- $cur)
            set -l rest (string replace -r '^[0-9]+/' '' -- $cur)
            __cdx_shorthand_dirs $num $rest ''
            return
        end
        if string match -rq '^[0-9]+$' -- $cur
            __cdx_shorthand_dirs $cur '' ''
            return
        end
        for n in (seq 1 9)
            echo $n
        end
        return
    end
end

complete -c cdx -f
complete -c cdx -s i -d "inspect mode — preview without changing directory"
complete -c cdx -s h -l help -d "show help"
complete -c cdx -s v -l version -d "show version"
complete -c cdx -l up -d "go up N parent levels" -x
complete -c cdx -a '(__cdx_complete)'
complete -c cdx -a '(__fish_complete_directories (commandline -ct))'
