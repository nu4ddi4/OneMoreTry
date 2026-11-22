#!/bin/sh
set -eu

if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --delete-signing-key ]; }; then
    printf '%s\n' 'Usage: remove-apt-registration.sh [--delete-signing-key]' >&2
    exit 2
fi

sudo rm -f /etc/apt/sources.list.d/onemoretry.list /etc/apt/keyrings/onemoretry.asc

if [ "$#" -eq 1 ]; then
    fingerprint=B5613B3734A09E1044E6FC48557940A365A6D220
    if gpg --batch --list-keys "$fingerprint" >/dev/null 2>&1; then
        printf 'Delete OneMoreTry OpenPGP key %s from your local keyring? [y/N] ' "$fingerprint"
        read -r answer
        case "$answer" in
            y|Y|yes|YES) gpg --batch --yes --delete-secret-and-public-key "$fingerprint" ;;
            *) printf '%s\n' 'The OpenPGP key was kept.' ;;
        esac
    fi
fi
