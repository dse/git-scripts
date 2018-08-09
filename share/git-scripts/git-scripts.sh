# -*- mode: sh; sh-shell: bash -*-

run () {
    if (( verbose || dry_run )) ; then
        >&2 echo "+ ${@@Q}"
    fi
    if (( dry_run )) ; then
        return
    fi
    "$@"
}
