#!/usr/bin/env bash
# Shared phase-0 preflight check for every Terraform use case (02 onward): the same
# "required CLI tools installed" + "real AWS or Floci credentials work" checks that
# used to be restated in prose in each use case's phase0-preflight.md.
set -euo pipefail

FAILURES=0

log() { printf '%s\n' "$*" >&2; }
pass() { printf 'PASS  %s\n' "$*" >&2; }
fail() { printf 'FAIL  %s\n' "$*" >&2; FAILURES=$((FAILURES + 1)); }

usage() {
    cat >&2 <<EOF
Usage: ${0##*/} --tools "terraform [helm kubectl ...]" [--floci-url URL]

Checks each listed CLI tool exits 0 on its version subcommand, then checks that either
real AWS credentials work (aws sts get-caller-identity) or a Floci emulator is
reachable at --floci-url (default http://localhost:4566, matching this repo's
use_floci Terraform variable). Exits nonzero if any tool check fails, or if neither
the real-AWS nor the Floci path is usable.
EOF
    exit 2
}

TOOLS=""
FLOCI_URL="http://localhost:4566"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tools) TOOLS="$2"; shift 2 ;;
        --floci-url) FLOCI_URL="$2"; shift 2 ;;
        *) usage ;;
    esac
done

[[ -n "${TOOLS}" ]] || usage

check_tools() {
    local tool
    for tool in ${TOOLS}; do
        local -a cmd
        case "${tool}" in
            kubectl) cmd=(kubectl version --client) ;;
            *) cmd=("${tool}" version) ;;
        esac
        if "${cmd[@]}" >/dev/null 2>&1; then
            pass "${tool}: installed (${cmd[*]})"
        else
            fail "${tool}: not installed, or '${cmd[*]}' exited nonzero"
        fi
    done
}

check_aws_or_floci() {
    if aws sts get-caller-identity >/dev/null 2>&1; then
        pass "real AWS credentials valid (aws sts get-caller-identity)"
        return
    fi
    if curl -sf "${FLOCI_URL}" >/dev/null 2>&1; then
        pass "Floci emulator reachable at ${FLOCI_URL} (target it with -var=\"use_floci=true\")"
        return
    fi
    fail "neither real AWS credentials nor a Floci emulator at ${FLOCI_URL} are usable"
}

main() {
    log "== preflight: tools=[${TOOLS}] =="
    check_tools
    check_aws_or_floci

    if [[ "${FAILURES}" -gt 0 ]]; then
        log "== preflight FAILED: ${FAILURES} check(s) =="
        exit 1
    fi
    log "== preflight PASSED =="
}

main
