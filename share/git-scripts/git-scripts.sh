# -*- mode: sh; sh-shell: bash -*-

declare -a _tempfiles

mktemp () {
    local tempfile="$(command mktemp "$@")"
    _tempfiles+=("${tempfile}")
    echo "${tempfile}"
}

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
    local exitstatus source current

    sed 's/^[ '$'\t'']*|//' >&2

    exitstatus="$1"; shift
    source="$1"; shift

    if [[ "${exitstatus}" == "" ]] ; then
        exitstatus=1
    else
        true
    fi

    if [[ -n "${source}" ]] ; then
        current="$(git rev-parse --abbrev-ref HEAD)"

        if [[ "${source}" != "" ]] && [[ "${current}" != "${source}" ]] ; then
            >&2 echo ""
            >&2 echo "    YOU ARE STILL IN BRANCH ${current}."
        else
            true
        fi
    fi

    local tempfile

    if (( ${#_tempfiles[@]} )) ; then
        /bin/rm "${_tempfiles[@]}"
    fi

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
