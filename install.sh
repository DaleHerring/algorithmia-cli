#!/bin/bash

set -e

main() {
    for cmd in curl tar gzip; do
        need_cmd $cmd
    done

    set_globals
    handle_command_line_args "$@"
}

set_globals() {
    algo_version="1.0.0-beta.3"
    default_prefix="${ALGO_PREFIX-/usr/local}"
    base_url="https://github.com/algorithmiaio/algorithmia-cli/releases/download"
    completions_url="https://github.com/algorithmiaio/algorithmia-cli/blob/master/completions"
}

set_architecture() {
    verbose_say "detecting architecture"

    local _ostype="$(uname -s)"
    local _cputype="$(uname -m)"

    verbose_say "uname -s reports: $_ostype"
    verbose_say "uname -m reports: $_cputype"

    if [ "$_ostype" = Darwin -a "$_cputype" = i386 ]; then
        # Darwin `uname -s` lies
        if sysctl hw.optional.x86_64 | grep -q ': 1'; then
            local _cputype=x86_64
        fi
    fi

    case "$_ostype" in

        Linux)
            local _ostype=unknown-linux-gnu
            ;;

        Darwin)
            local _ostype=apple-darwin
            ;;

        MINGW* | MSYS* | CYGWIN*)
            local _ostype=pc-windows-gnu
            ;;

        *)
            err "unrecognized OS type: $_ostype"
            ;;

    esac

    case "$_cputype" in

        i386 | i486 | i686 | i786 | x86)
            local _cputype=i686
            ;;

        x86_64 | x86-64 | x64 | amd64)
            local _cputype=x86_64
            ;;

        *)
            err "unknown CPU type: $_cputype"

    esac

    # Detect 64-bit linux with 32-bit userland
    if [ $_ostype = unknown-linux-gnu -a $_cputype = x86_64 ]; then
        # $SHELL does not exist in standard 'sh', so probably only exists
        # if configure is running in an interactive bash shell. /usr/bin/env
        # exists *everywhere*.
        local _bin_to_probe="${SHELL-bogus_shell}"
        if [ ! -e "$_bin_to_probe" -a -e "/usr/bin/env" ]; then
            _bin_to_probe="/usr/bin/env"
        fi
        # $SHELL may be not a binary
        if [ -e "$_bin_to_probe" ]; then
            file -L "$_bin_to_probe" | grep -q "text" || _bin_to_probe="/usr/bin/env"
        fi
        if [ -e "$_bin_to_probe" ]; then
            file -L "$_bin_to_probe" | grep -q "x86[_-]64" || local _cputype=i686
        fi
    fi

    _algo_arch="$_cputype-$_ostype"
    verbose_say "architecture is $_algo_arch"
}

print_welcome_message() {
    local _prefix="$1"
    local _uninstall="$2"
    local _disable_sudo="$3"

    cat <<"EOF"

    /\
   /  \     Welcome to Algorithmia
  /    \    Command Line Tools
 /\    /\
/  \  /  \

EOF

    if [ "$_disable_sudo" = false ]; then
        if [ "$(id -u)" = 0 ]; then
            cat <<EOF
WARNING: This script appears to be running as root. While it will work
correctly, it is not necessary to run this install script as root.

EOF
        fi
    fi


    if [ "$_uninstall" = false ]; then
        cat <<EOF
This script will download algo and install it to $_prefix.
You may install elsewhere by running this script with the --prefix=<path> option.

EOF
    else
        cat <<EOF
This script will uninstall the existing algo installation at $_prefix.

EOF
    fi

    if [ "$_disable_sudo" = false ]; then
        cat <<EOF
The installer will run under 'sudo' and may ask you for your password. If you do
not want the script to run 'sudo' then pass it the --disable-sudo flag.

EOF
    fi

    if [ "$_uninstall" = false ]; then
        cat <<EOF
You may uninstall later by running $_prefix/lib/algo/uninstall.sh,
or by running this script again with the --uninstall flag.

EOF
    fi

    echo
}


handle_command_line_args() {
    local _prefix="$default_prefix"
    local _uninstall=false
    local _help=false
    local _disable_sudo=false

    local _arg
    for _arg in "$@"; do
        case "${_arg%%=*}" in
            --uninstall )
                _uninstall=true
                ;;

            -h | --help )
                _help=true
                ;;

            --verbose)
                # verbose is a global flag
                flag_verbose=true
                ;;

            --disable-sudo)
                _disable_sudo=true
                ;;

            -y | --yes)
                # yes is a global flag
                flag_yes=true
                ;;

            --prefix)
                if is_value_arg "$_arg" "prefix"; then
                    _prefix="$(get_value_arg "$_arg")"
                fi
                ;;

            *)
                echo "Unknown argument '$_arg', displaying usage:"
                echo ${_arg%%=*}
                _help=true
                ;;

        esac

    done

    if [ "$_help" = true ]; then
        print_help
        exit 0
    fi

    print_welcome_message $_prefix $_uninstall $_disable_sudo
    set_architecture

    if [ "$_uninstall" = true ]; then
        uninstall_cli
    else
        install_cli
    fi

}

install_cli() {
    # download algo for platform
    local tmpdir=$(mktemp -d)
    cd $tmpdir
    verbose_say "working directory: '$tmpdir'"

    local release_url="${base_url}/v${algo_version}/algorithmia-v${algo_version}-${_algo_arch}.tar.gz"
    verbose_say "downloading release tarball..."
    curl -sSL "$release_url" -o "algo.tar.gz"

    verbose_say "extracting release tarball..."
    tar -xzf algo.tar.gz

    verbose_say "downloading completions..."
    mkdir $tmpdir/zsh && cd $tmpdir/zsh && curl -sSL -O "${completions_url}/zsh/_algo"
    mkdir $tmpdir/bash && cd $tmpdir/bash && curl -sSL -O "${completions_url}/bash/algo"

    # copy to $_prefix/bin
    say "TODO: install algo"

    # install completions
    say "TODO: install completions"
}

uninstall_cli() {
    say "TODO: uninstall"
}

print_help() {
echo '
Usage: install-algo.sh [--verbose]
Options:
     --prefix=<path>                   Install to a specific location (default /usr/local)
     --uninstall                       Uninstall instead of install
     --disable-sudo                    Do not run installer under sudo
     --yes, -y                         Disable the interactive mode
     --help, -h                        Display usage information
'
}

say() {
    echo "install-algo: $1"
}

say_err() {
    say "$1" >&2
}

verbose_say() {
    if [ "$flag_verbose" = true ]; then
        say "$1"
    fi
}

err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! command -v "$1" > /dev/null 2>&1; then
        err "need '$1' (command not found)"
    fi
}

main "$@"