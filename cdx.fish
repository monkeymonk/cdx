# cdx — extensible cd wrapper (fish port)

set -g __CDX_VERSION "0.3.0"
set -g __CDX_LOADED 1
set -g __CDX_HOOKS_SYNC
set -g __CDX_HOOKS_ASYNC
set -g __CDX_RESOLVER_ORDER zoxide z zlua autojump
set -g __CDX_RESOLVERS_CACHED
set -g __CDX_RESOLVERS_DIRTY 1
# Parallel arrays model an associative map (fish has no assoc arrays).
set -g __CDX_HOOK_NAMES
set -g __CDX_HOOK_CONTEXTS

function _cdx_usage
    printf "cdx — extensible cd wrapper\nVersion: v%s\n" $__CDX_VERSION
    echo "Usage:"
    echo "  cdx [options] [dir]"
    echo "  cdx -i [dir]"
    echo "  cdx --up [N[/subpath]]"
    echo "  cdx -N[/subpath]"
    echo ""
    echo "Options:"
    echo "  -i            Inspect mode (run hooks without changing directory)"
    echo "  --up [N]      Go up N parent levels (default: 1)"
    echo "  -N            Shorthand for --up N (e.g. -3, -2/src)"
    echo "  -h, --help    Show this help message"
    echo "  -v, --version Show the cdx version"
    echo ""
    echo "Examples:"
    echo "  cdx /tmp"
    echo "  cdx -i /tmp"
    echo "  cdx --up"
    echo "  cdx --up 2"
    echo "  cdx --up 2/src"
    echo "  cdx -3"
    echo "  cdx -2/src"
    echo "  cdx -- /path"
end

function _cdx_version
    printf "cdx v%s\n" $__CDX_VERSION
end

function cdx_register_hook --argument-names type fn ctx
    test -z "$ctx"; and set ctx interactive
    switch $ctx
        case interactive noninteractive all
        case '*'
            echo "cdx: unknown hook context: $ctx (use interactive, noninteractive, or all)" >&2
            return 1
    end
    set -l idx (contains -i -- $fn $__CDX_HOOK_NAMES)
    if test -n "$idx"
        set __CDX_HOOK_CONTEXTS[$idx] $ctx
        return 0
    end
    switch $type
        case sync
            set -a __CDX_HOOKS_SYNC $fn
        case async
            set -a __CDX_HOOKS_ASYNC $fn
        case '*'
            echo "cdx: unknown hook type: $type" >&2
            return 1
    end
    set -a __CDX_HOOK_NAMES $fn
    set -a __CDX_HOOK_CONTEXTS $ctx
end

# --- Directory resolvers ---

function _cdx_resolver_zoxide --argument-names query
    type -q zoxide; or return 1
    zoxide query -- $query 2>/dev/null
end

function _cdx_resolver_z --argument-names query
    functions -q z; or return 1
    z -e $query 2>/dev/null
end

function _cdx_resolver_zlua --argument-names query
    functions -q _zlua; or return 1
    _zlua -e $query 2>/dev/null
end

function _cdx_resolver_autojump --argument-names query
    type -q autojump; or return 1
    set -l result (autojump $query 2>/dev/null)
    if test -n "$result" -a -d "$result"
        echo $result
    else
        return 1
    end
end

function _cdx_cache_resolvers
    set -g __CDX_RESOLVERS_CACHED
    if set -q CDX_RESOLVERS
        set -g __CDX_RESOLVERS_CACHED $CDX_RESOLVERS
    else
        for name in $__CDX_RESOLVER_ORDER
            if functions -q _cdx_resolver_$name
                set -a __CDX_RESOLVERS_CACHED $name
            end
        end
    end
    set -g __CDX_RESOLVERS_DIRTY 0
end

function _cdx_resolve --argument-names query
    if test "$__CDX_RESOLVERS_DIRTY" = "1"
        _cdx_cache_resolvers
    else if test (count $__CDX_RESOLVERS_CACHED) -eq 0
        _cdx_cache_resolvers
    else if set -q CDX_RESOLVERS
        _cdx_cache_resolvers
    end

    for name in $__CDX_RESOLVERS_CACHED
        set -l result (_cdx_resolver_$name $query 2>/dev/null)
        set -l rc $status
        if test $rc -eq 0 -a -n "$result"
            echo $result
            return 0
        end
    end
    return 1
end

function _cdx_dispatch --argument-names mode resolved
    set -l shell_ctx noninteractive
    status --is-interactive; and set shell_ctx interactive

    for fn in $__CDX_HOOKS_SYNC
        set -l idx (contains -i -- $fn $__CDX_HOOK_NAMES)
        set -l ctx interactive
        test -n "$idx"; and set ctx $__CDX_HOOK_CONTEXTS[$idx]
        if test "$ctx" = "$shell_ctx" -o "$ctx" = "all"
            functions -q $fn; and $fn $mode $resolved
        end
    end
    for fn in $__CDX_HOOKS_ASYNC
        set -l idx (contains -i -- $fn $__CDX_HOOK_NAMES)
        set -l ctx interactive
        test -n "$idx"; and set ctx $__CDX_HOOK_CONTEXTS[$idx]
        if test "$ctx" = "$shell_ctx" -o "$ctx" = "all"
            if functions -q $fn
                begin
                    $fn $mode $resolved
                end >/dev/null 2>&1 &
                disown 2>/dev/null
            end
        end
    end
end

function cdx
    if not set -q __CDX_LOADED
        builtin cd $argv
        return
    end

    set -l inspect 0
    set -l up_mode 0
    set -l up_spec ""
    set -l dir ""
    set -l stop_parse 0

    while test (count $argv) -gt 0
        if test $stop_parse -eq 1
            set dir $argv[1]
            break
        end
        switch $argv[1]
            case '-i'
                set inspect 1
                set -e argv[1]
            case '--up'
                set up_mode 1
                if test (count $argv) -ge 2
                    if string match -rq '^[0-9]+(/.*)?$' -- $argv[2]
                        set up_spec $argv[2]
                        set -e argv[2]
                    end
                end
                set -e argv[1]
            case '-h' '--help'
                _cdx_usage
                return 0
            case '-v' '--version'
                _cdx_version
                return 0
            case '--'
                set stop_parse 1
                set -e argv[1]
            case '-*'
                set -l stripped (string sub -s 2 -- $argv[1])
                if string match -rq '^[0-9]+(/.*)?$' -- $stripped
                    set up_mode 1
                    set up_spec $stripped
                else
                    test -z "$dir"; and set dir $argv[1]
                end
                set -e argv[1]
            case '*'
                test -z "$dir"; and set dir $argv[1]
                set -e argv[1]
        end
    end

    if test $up_mode -eq 1
        set -l count 1
        set -l subpath ""
        if test -n "$up_spec"
            set -l num (string split -m 1 / -- $up_spec)[1]
            if string match -rq '^[0-9]+$' -- $num; and test $num -gt 0
                set count $num
                if string match -q '*/*' -- $up_spec
                    set subpath (string split -m 1 / -- $up_spec)[2]
                end
            else
                echo "cdx: invalid --up spec: $up_spec" >&2
                return 1
            end
        end
        set -l target ""
        for i in (seq $count)
            set target "../$target"
        end
        test -n "$subpath"; and set target "$target$subpath"
        test -z "$target"; and set target ".."
        if test $inspect -eq 1
            cdx -i $target
        else
            cdx $target
        end
        return
    end

    set -l target $HOME
    test -n "$dir"; and set target $dir
    set -l resolved_target ""
    if not test -d $target
        set resolved_target (_cdx_resolve $target 2>/dev/null)
    end
    test -z "$resolved_target"; and set resolved_target $target

    set -l mode ""
    set -l resolved ""
    if test $inspect -eq 1
        set mode inspect
        set -l saved_pwd $PWD
        if builtin cd $resolved_target 2>/dev/null
            set resolved $PWD
            builtin cd $saved_pwd
        else
            echo "cdx: no such directory: $target" >&2
            return 1
        end
        echo $resolved
    else
        set mode enter
        if not builtin cd $resolved_target 2>/dev/null
            echo "cdx: no such directory: $target" >&2
            return 1
        end
        set resolved $PWD
    end

    if test "$CDX_CDXRC" != "0"
        set -l cdxrc "$resolved/.cdxrc.fish"
        test -f $cdxrc; and source $cdxrc
    end

    _cdx_dispatch $mode $resolved
end

function _cdx_init
    set -l config_dir "$HOME/.config/cdx"
    set -q CDX_CONFIG_DIR; and set config_dir $CDX_CONFIG_DIR
    set -l config "$config_dir/config.fish"
    test -f $config; and source $config

    set -l hooks_dir "$config_dir/hooks"
    for name in $CDX_HOOKS_ENABLED
        set -l hook_file "$hooks_dir/$name.fish"
        if test -f $hook_file
            source $hook_file
        else
            echo "cdx: hook not found: $name" >&2
        end
    end

    _cdx_cache_resolvers
end

if status --is-interactive
    _cdx_init

    # Auto-load completions if they live next to this script.
    set -l __cdx_script_dir (dirname (status filename))
    if test -f "$__cdx_script_dir/completions/cdx.fish"
        source "$__cdx_script_dir/completions/cdx.fish"
    end
    set -e __cdx_script_dir
end
