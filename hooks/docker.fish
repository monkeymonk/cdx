# cdx hook: docker — switch docker context on enter

function cdx_hook_docker --argument-names mode dir
    test "$mode" = enter; or return 0  # enter only — avoid switching context in inspect mode
    set -l context_file "$dir/.docker-context"
    test -f $context_file; or return 0
    type -q docker; or return 0
    set -l context (read -l < $context_file)
    test -n "$context"; or return 0
    docker context use $context
end

cdx_register_hook async cdx_hook_docker
