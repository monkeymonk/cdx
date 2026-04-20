# cdx hook: preview — show directory contents on enter

if not set -q __CDX_LS_CMD
    if type -q eza
        set -g __CDX_LS_CMD eza
    else if type -q exa
        set -g __CDX_LS_CMD exa
    else
        set -g __CDX_LS_CMD ls
    end
end

function cdx_hook_preview --argument-names mode dir
    # runs on both enter and inspect — intentional: inspect previews without navigating
    set -l args $CDX_LS_ARGS
    test (count $args) -eq 0; and set args --color=auto
    $__CDX_LS_CMD $args $dir
end

cdx_register_hook sync cdx_hook_preview
