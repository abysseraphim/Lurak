#!/usr/bin/env bash
#
# install.sh - sets up Lurak on your machine.
#
# Run this from inside the Lurak folder (next to lurak.bash):
#   chmod +x install.sh && ./install.sh
#
# It walks through everything Lurak depends on, asks before installing
# anything, then wires up lurak.bash so you can just type `lurak` from
# anywhere.
#
set -uo pipefail

# ---------------------------------------------------------------------------
# little helpers for colored output + yes/no prompts
# ---------------------------------------------------------------------------
C_RESET="\033[0m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_CYAN="\033[1;36m"

info()  { printf "%b[*]%b %s\n" "$C_CYAN"   "$C_RESET" "$1"; }
ok()    { printf "%b[+]%b %s\n" "$C_GREEN"  "$C_RESET" "$1"; }
warn()  { printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$1"; }
err()   { printf "%b[-]%b %s\n" "$C_RED"    "$C_RESET" "$1"; }

# nothing gets installed without the user saying yes - default is no
# if they just hit enter
confirm() {
    local prompt="$1"
    local reply
    read -rp "$(printf "%b[?]%b %s [y/N]: " "$C_YELLOW" "$C_RESET" "$prompt")" reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# are we root already, or do we need sudo for installs?
need_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo "sudo"
    else
        echo ""
    fi
}
SUDO=$(need_sudo)

# ---------------------------------------------------------------------------
# figure out where the real Lurak folder is. install.sh might get run
# through a symlink itself someday, so we resolve that properly instead
# of just trusting $0.
# ---------------------------------------------------------------------------
resolve_script_dir() {
    local src="${BASH_SOURCE[0]}"
    while [ -h "$src" ]; do
        local dir
        dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd
}
LURAK_DIR="$(resolve_script_dir)"

# quick sanity check - if lurak.bash isn't sitting right here, something's wrong
if [[ ! -f "$LURAK_DIR/lurak.bash" ]]; then
    err "lurak.bash not found in $LURAK_DIR — run install.sh from inside the Lurak repo."
    exit 1
fi

info "Lurak repo detected at: $LURAK_DIR"
echo

# ---------------------------------------------------------------------------
# this installer only really knows how to talk to apt. anything else and
# we just warn and let the user handle system packages themselves - the
# go tools further down will still work fine either way.
# ---------------------------------------------------------------------------
if ! command -v apt-get >/dev/null 2>&1; then
    warn "This installer only automates apt-based systems (Debian/Ubuntu)."
    warn "Your package manager wasn't detected as apt. You'll need to install"
    warn "system tools manually; Go-tool installation can still proceed."
    HAVE_APT=0
else
    HAVE_APT=1
fi

# only run "apt-get update" once, no matter how many packages we end up installing
APT_UPDATED=0
apt_update_once() {
    if [[ $APT_UPDATED -eq 0 ]]; then
        info "Running apt-get update..."
        $SUDO apt-get update -y
        APT_UPDATED=1
    fi
}

# ---------------------------------------------------------------------------
# checks if a command exists, and if not, offers to apt-install it.
# usage: check_apt_tool <command> <apt-package> [nice name to print]
# ---------------------------------------------------------------------------
check_apt_tool() {
    local bin="$1"
    local pkg="$2"
    local label="${3:-$bin}"

    if command -v "$bin" >/dev/null 2>&1; then
        ok "$label already installed."
        return 0
    fi

    warn "$label ('$bin') not found."

    if [[ $HAVE_APT -eq 0 ]]; then
        err "Skipping $label — no apt available, install it manually."
        return 1
    fi

    if confirm "Install $label via 'apt-get install $pkg'?"; then
        apt_update_once
        if $SUDO apt-get install -y "$pkg"; then
            ok "$label installed."
        else
            err "Failed to install $label. You'll need to install it manually."
            return 1
        fi
    else
        warn "Skipped $label — Lurak modules that need it won't work."
    fi
}

# ---------------------------------------------------------------------------
# the plain system tools Lurak's modules shell out to
# ---------------------------------------------------------------------------
info "=== Checking system tools ==="
check_apt_tool nmap    nmap                "nmap"
check_apt_tool whois   whois               "whois"
check_apt_tool dig     dnsutils            "dig (dnsutils)"
check_apt_tool curl    curl                "curl"
check_apt_tool openssl openssl             "openssl"
check_apt_tool jq      jq                  "jq"
check_apt_tool psql    postgresql-client   "psql (postgresql-client)"
check_apt_tool nc      netcat-openbsd      "nc (netcat)"
check_apt_tool crunch  crunch              "crunch"
echo

# massdns isn't packaged in Debian/Ubuntu's repos, so if it's missing
# we just build it from source instead.
install_massdns() {
    if command -v massdns >/dev/null 2>&1; then
        ok "massdns already installed."
        return 0
    fi

    warn "massdns not found."
    if ! confirm "Build & install massdns from source (github.com/blechschmidt/massdns)?"; then
        warn "Skipped massdns — DNS Brute Force module needs it."
        return 1
    fi

    if [[ $HAVE_APT -eq 1 ]]; then
        apt_update_once
        $SUDO apt-get install -y git build-essential
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    if git clone --depth 1 https://github.com/blechschmidt/massdns.git "$tmpdir/massdns" \
        && make -C "$tmpdir/massdns" \
        && $SUDO cp "$tmpdir/massdns/bin/massdns" /usr/local/bin/massdns; then
        ok "massdns installed to /usr/local/bin/massdns."
    else
        err "Failed to build/install massdns. Install it manually."
    fi
    rm -rf "$tmpdir"
}
info "=== Checking massdns ==="
install_massdns
echo

# ---------------------------------------------------------------------------
# Go needs to exist before any of the go install-based tools below can work
# ---------------------------------------------------------------------------
info "=== Checking Go ==="
GO_BIN=""
if command -v go >/dev/null 2>&1; then
    ok "Go already installed ($(go version))."
    GO_BIN="go"
else
    warn "Go is not installed. Several Lurak tools (subfinder, naabu, dnsx, ...) need it."
    if confirm "Install Go via apt ('golang-go')?"; then
        if [[ $HAVE_APT -eq 1 ]]; then
            apt_update_once
            if $SUDO apt-get install -y golang-go; then
                ok "Go installed."
                GO_BIN="go"
            else
                err "apt install of Go failed. Install Go manually from https://go.dev/dl/"
            fi
        else
            err "No apt available — install Go manually from https://go.dev/dl/"
        fi
    else
        warn "Skipped Go — Go-based tools below will be skipped too."
    fi
fi
echo

# go install drops binaries in ~/go/bin, which usually isn't on PATH by
# default - make sure it is, both for right now and for future shells.
GOPATH_BIN="$HOME/go/bin"
ensure_gopath_on_path() {
    mkdir -p "$GOPATH_BIN"
    case ":$PATH:" in
        *":$GOPATH_BIN:"*) ;;
        *) export PATH="$PATH:$GOPATH_BIN" ;;
    esac

    local rc=""
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        rc="$HOME/.zshrc"
    else
        rc="$HOME/.bashrc"
    fi

    if [[ -f "$rc" ]] && ! grep -q 'go/bin' "$rc"; then
        if confirm "Add \$HOME/go/bin to PATH permanently in $rc?"; then
            echo 'export PATH=$PATH:$HOME/go/bin' >> "$rc"
            ok "Added to $rc (restart your shell or 'source $rc' to pick it up)."
        fi
    fi
}

# ---------------------------------------------------------------------------
# same idea as check_apt_tool, but for the go install-based recon tools
# usage: check_go_tool <binary> <go module path>
# ---------------------------------------------------------------------------
check_go_tool() {
    local bin="$1"
    local pkg="$2"

    if command -v "$bin" >/dev/null 2>&1; then
        ok "$bin already installed."
        return 0
    fi

    if [[ -z "$GO_BIN" ]]; then
        warn "Skipping $bin — Go isn't installed."
        return 1
    fi

    warn "$bin not found."
    if confirm "Install $bin via 'go install $pkg'?"; then
        if go install "$pkg"; then
            ok "$bin installed to \$HOME/go/bin."
        else
            err "Failed to install $bin."
            return 1
        fi
    else
        warn "Skipped $bin — Lurak modules that need it won't work."
    fi
}

if [[ -n "$GO_BIN" ]]; then
    ensure_gopath_on_path
    info "=== Checking Go-based recon tools ==="
    check_go_tool subfinder    github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    check_go_tool naabu        github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
    check_go_tool dnsx         github.com/projectdiscovery/dnsx/cmd/dnsx@latest
    check_go_tool shuffledns   github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
    check_go_tool waybackurls  github.com/tomnomnom/waybackurls@latest
    check_go_tool gau          github.com/lc/gau/v2/cmd/gau@latest
    check_go_tool unfurl       github.com/tomnomnom/unfurl@latest
    check_go_tool anew         github.com/tomnomnom/anew@latest
    check_go_tool dnsgen       github.com/ProjectAnte/dnsgen@latest 2>/dev/null || true
    echo
fi

# ---------------------------------------------------------------------------
# lurak.bash sources its lib/ui/module files using paths that are relative
# to wherever you happen to be standing (cwd) when you run it. that's fine
# if you always cd into the repo first, but it breaks the second you run
# it through a symlink from somewhere else - it'll go looking for lib/...
# in the wrong place and blow up.
#
# so, one-time and idempotent, we tack a small bit of self-location logic
# onto the top of lurak.bash: it figures out where it *actually* lives
# (following symlinks) and cd's there before sourcing anything else.
# after that, running `lurak` from any directory just works.
# ---------------------------------------------------------------------------
patch_lurak_for_symlink() {
    local target="$LURAK_DIR/lurak.bash"

    if grep -q "LURAK_SELF_RESOLVE_PATCH" "$target"; then
        ok "lurak.bash already patched for symlink-safe execution."
        return 0
    fi

    info "Patching lurak.bash so it works correctly when run via a symlink..."

    local tmp
    tmp=$(mktemp)
    {
        echo '#!/usr/bin/env bash'
        echo ''
        echo '# LURAK_SELF_RESOLVE_PATCH — added by install.sh'
        echo '# figures out where this script really lives, even if launched via'
        echo '# a symlink, so the relative `source` lines below still find their files'
        echo '__lurak_src="${BASH_SOURCE[0]}"'
        echo 'while [ -h "$__lurak_src" ]; do'
        echo '    __lurak_dir="$(cd -P "$(dirname "$__lurak_src")" >/dev/null 2>&1 && pwd)"'
        echo '    __lurak_src="$(readlink "$__lurak_src")"'
        echo '    [[ "$__lurak_src" != /* ]] && __lurak_src="$__lurak_dir/$__lurak_src"'
        echo 'done'
        echo '__lurak_dir="$(cd -P "$(dirname "$__lurak_src")" >/dev/null 2>&1 && pwd)"'
        echo 'cd "$__lurak_dir" || exit 1'
        echo ''
        # everything that was already in the file, minus the old shebang line
        tail -n +2 "$target"
    } > "$tmp"

    mv "$tmp" "$target"
    chmod +x "$target"
    ok "lurak.bash patched."
}
patch_lurak_for_symlink
echo

# ---------------------------------------------------------------------------
# make sure lurak.bash is actually runnable
# ---------------------------------------------------------------------------
chmod +x "$LURAK_DIR/lurak.bash"
ok "lurak.bash is executable."
echo

# ---------------------------------------------------------------------------
# last step: drop a symlink somewhere on PATH so you can just type `lurak`
# instead of typing out the full path every time
# ---------------------------------------------------------------------------
info "=== Linking 'lurak' into your PATH ==="

# prefer /usr/local/bin (system-wide, works for everyone on the box),
# fall back to ~/.local/bin if we can't write there
pick_link_dir() {
    if [[ -d /usr/local/bin ]] && [[ -w /usr/local/bin || -n "$SUDO" ]]; then
        echo "/usr/local/bin"
    else
        mkdir -p "$HOME/.local/bin"
        echo "$HOME/.local/bin"
    fi
}

LINK_DIR="$(pick_link_dir)"
LINK_PATH="$LINK_DIR/lurak"

if [[ -e "$LINK_PATH" || -L "$LINK_PATH" ]]; then
    if confirm "'$LINK_PATH' already exists. Overwrite it?"; then
        $SUDO rm -f "$LINK_PATH"
    else
        warn "Skipped symlink creation."
        LINK_PATH=""
    fi
fi

if [[ -n "$LINK_PATH" ]]; then
    if $SUDO ln -s "$LURAK_DIR/lurak.bash" "$LINK_PATH"; then
        ok "Symlinked: $LINK_PATH -> $LURAK_DIR/lurak.bash"
    else
        err "Failed to create symlink at $LINK_PATH."
    fi

    # if we had to fall back to ~/.local/bin, that might not be on PATH yet
    if [[ "$LINK_DIR" == "$HOME/.local/bin" ]]; then
        case ":$PATH:" in
            *":$HOME/.local/bin:"*) ;;
            *)
                warn "$HOME/.local/bin is not on your PATH."
                rc="$HOME/.bashrc"
                [[ -n "${ZSH_VERSION:-}" ]] && rc="$HOME/.zshrc"
                if confirm "Add \$HOME/.local/bin to PATH in $rc?"; then
                    echo 'export PATH=$PATH:$HOME/.local/bin' >> "$rc"
                    ok "Added. Restart your shell or 'source $rc'."
                fi
                ;;
        esac
    fi
fi

echo
ok "Done. Once PATH is refreshed, run Lurak from anywhere with: lurak"
