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

croak () {
    sed 's/^[ '$'\t'']*|//' >&2

    local exitstatus="$1"; shift
    local source="$1"; shift

    if [[ "${exitstatus}" == "" ]] ; then
        exitstatus=1
    else true ; fi

    local current
    current="$(git rev-parse --abbrev-ref HEAD)"

    if [[ "${source}" != "" ]] && [[ "${current}" != "${source}" ]] ; then
        >&2 echo ""
        >&2 echo "    YOU ARE STILL IN BRANCH ${current}."
    else true ; fi

    >&2 echo
    >&2 echo "Exiting."
    exit "${exitstatus}"
}

sendoff () {
    sed 's/^[ '$'\t'']*|//' >&2
    exit 0
}

set_heredoc () {
    local varname="$1"
    IFS='' read -r -d '' "${varname}" || true
}
