# cdx hook: git — show git status on enter

function cdx_hook_git --argument-names mode dir
    # runs on both enter and inspect — intentional: inspect shows status without navigating
    test -d "$dir/.git"; or return 0
    type -q git; or return 0
    git -C $dir status -sb
end

cdx_register_hook sync cdx_hook_git
