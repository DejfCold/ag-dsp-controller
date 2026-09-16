#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="ag-dsp-controller"
DATA_DIR="/usr/share/${PACKAGE_NAME}"
STATE_DIR="/var/lib/${PACKAGE_NAME}"
REMOVE_USER_STATE=0
ASSUME_YES=0

for argument in "$@"; do
    case "${argument}" in
        --remove-user-state) REMOVE_USER_STATE=1 ;;
        --yes) ASSUME_YES=1 ;;
        *)
            echo "Unknown option: ${argument}" >&2
            echo "Usage: ${0} [--yes] [--remove-user-state]" >&2
            exit 2
            ;;
    esac
done

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run the uninstaller as root, for example: sudo ${0}" >&2
    exit 1
fi

echo "This will remove the downloaded Yamaha controller files and installer state."
if [[ "${REMOVE_USER_STATE}" -eq 1 ]]; then
    echo "It will also remove the current user's Wine state."
else
    echo "The per-user Wine state will be preserved."
fi
if [[ "${ASSUME_YES}" -eq 0 ]]; then
    read -r -p "Continue? [y/N] " answer
    case "${answer}" in
        y|Y|yes|YES) ;;
        *) echo "Uninstallation cancelled."; exit 0 ;;
    esac
fi

rm -f -- "${DATA_DIR}/current" "${DATA_DIR}/ag_dsp_controller.exe"
rm -rf -- "${DATA_DIR}/releases"
find "${DATA_DIR}" -maxdepth 1 -type f -name '*Presets.csv' -delete 2>/dev/null || true
rm -rf -- "${STATE_DIR}"

if [[ "${REMOVE_USER_STATE}" -eq 1 && -n "${SUDO_USER:-}" ]]; then
    user_home="$(getent passwd "${SUDO_USER}" | awk -F: '{print $6}')"
    if [[ -n "${user_home}" && "${user_home}" != "/" ]]; then
        rm -rf -- "${user_home}/.local/share/${PACKAGE_NAME}"
    fi
fi

if command -v dnf >/dev/null 2>&1 && command -v rpm >/dev/null 2>&1 \
    && rpm -q "${PACKAGE_NAME}" >/dev/null 2>&1; then
    if [[ "${ASSUME_YES}" -eq 1 ]]; then
        exec dnf remove --assumeyes "${PACKAGE_NAME}"
    else
        exec dnf remove "${PACKAGE_NAME}"
    fi
elif command -v apt-get >/dev/null 2>&1 && command -v dpkg-query >/dev/null 2>&1 \
    && dpkg-query --status "${PACKAGE_NAME}" >/dev/null 2>&1; then
    if [[ "${ASSUME_YES}" -eq 1 ]]; then
        exec apt-get remove --yes "${PACKAGE_NAME}"
    else
        exec apt-get remove "${PACKAGE_NAME}"
    fi
else
    echo "Package ${PACKAGE_NAME} is not installed; downloaded files were removed." >&2
fi
