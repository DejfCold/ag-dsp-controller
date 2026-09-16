#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="ag-dsp-controller"
DATA_DIR="/usr/share/${PACKAGE_NAME}"
STATE_DIR="/var/lib/${PACKAGE_NAME}"
RELEASES_DIR="${DATA_DIR}/releases"
LICENSE_MARKER="${STATE_DIR}/yamaha-license.accepted"
LICENSE_URL="https://usa.yamaha.com/support/updates/ag_dsp_win.html"
URL="https://usa.yamaha.com/files/download/software/6/827126/AG_DSP_Controller_v1100_win.zip"
SHA256="2b2a7af814be568bf65885b9514b492565cdf0a9d42d0620ffe7ab24069de117"
ACCEPT_EULA=0
EXPECTED_LICENSE_HASH=""
LICENSE_FILE=""

for argument in "$@"; do
    case "${argument}" in
        --package-install) ;;
        --accept-eula|--accept-eula=true) ACCEPT_EULA=1 ;;
        --accept-eula=false) ACCEPT_EULA=0 ;;
        --expected-license-hash=*) EXPECTED_LICENSE_HASH="${argument#*=}" ;;
        --license-file=*) LICENSE_FILE="${argument#*=}" ;;
        *)
            echo "Unknown option: ${argument}" >&2
            echo "Usage: ${0} [--package-install] [--accept-eula] [--license-file=PATH]" >&2
            exit 2
            ;;
    esac
done

if [[ "${EUID}" -ne 0 ]]; then
    echo "The Yamaha controller installer must run as root for shared application files." >&2
    exit 1
fi

# pkexec supplies PKEXEC_UID; sudo supplies SUDO_UID. Both identify the
# desktop user whose Wine prefix must own and execute the Windows installer.
TARGET_UID="${AG06_INSTALL_UID:-${PKEXEC_UID:-${SUDO_UID:-}}}"
if [[ ! "${TARGET_UID}" =~ ^[0-9]+$ || "${TARGET_UID}" -eq 0 ]]; then
    echo "Refusing to run Wine as root. Start the controller normally so pkexec can identify the user, or run this command through sudo from a user session." >&2
    exit 1
fi
TARGET_USER="$(getent passwd "${TARGET_UID}" | awk -F: '{print $1}')"
TARGET_HOME="$(getent passwd "${TARGET_UID}" | awk -F: '{print $6}')"
[[ -n "${TARGET_USER}" && -n "${TARGET_HOME}" ]] || {
    echo "Could not resolve the unprivileged target user for UID ${TARGET_UID}." >&2
    exit 1
}
TARGET_GROUP="$(id -gn "${TARGET_USER}")"

for tool in curl unzip runuser getent id flock wine wineboot; do
    command -v "${tool}" >/dev/null || {
        echo "Missing required command '${tool}'. Install Wine, curl, unzip, and util-linux." >&2
        exit 1
    }
done
WINE_BOOT_BIN="${WINE_BOOT_BIN:-$(command -v wineboot || command -v wine)}"
WINE_BIN="${WINE_BIN:-$(command -v wine || true)}"

tmpdir="$(mktemp -d -t ag-dsp-controller.XXXXXX)"
trap 'rm -rf -- "${tmpdir}"' EXIT
mkdir -p "${STATE_DIR}" "${DATA_DIR}" "${RELEASES_DIR}"
exec 9>"${STATE_DIR}/install.lock"
flock 9
mkdir -p "${tmpdir}/source" "${tmpdir}/wine-prefix"
[[ -s "${DATA_DIR}/alsa-midi-name-shim.so" ]] || {
    echo "The Wine ALSA MIDI name shim is missing from the package." >&2
    exit 1
}

license_downloaded=1
if [[ -n "${LICENSE_FILE}" ]]; then
    if [[ ! -r "${LICENSE_FILE}" ]]; then
        echo "The supplied Yamaha license file is not readable: ${LICENSE_FILE}" >&2
        exit 1
    fi
    cp -- "${LICENSE_FILE}" "${tmpdir}/LICENSE-YAMAHA.html"
elif ! curl --fail --location --retry 3 --output "${tmpdir}/LICENSE-YAMAHA.html" "${LICENSE_URL}"; then
    license_downloaded=0
elif ! grep -Fq "PLEASE READ THIS SOFTWARE LICENSE AGREEMENT" "${tmpdir}/LICENSE-YAMAHA.html" \
    || ! grep -Fq "AG DSP Controller" "${tmpdir}/LICENSE-YAMAHA.html"; then
    license_downloaded=0
fi
if [[ "${license_downloaded}" -eq 1 ]] \
    && { ! grep -Fq "PLEASE READ THIS SOFTWARE LICENSE AGREEMENT" "${tmpdir}/LICENSE-YAMAHA.html" \
        || ! grep -Fq "AG DSP Controller" "${tmpdir}/LICENSE-YAMAHA.html"; }; then
    license_downloaded=0
fi

if [[ "${license_downloaded}" -eq 1 ]]; then
    license_hash="$(sha256sum "${tmpdir}/LICENSE-YAMAHA.html" | awk '{print $1}')"
    if [[ -n "${EXPECTED_LICENSE_HASH}" && "${EXPECTED_LICENSE_HASH}" != "${license_hash}" ]]; then
        echo "The Yamaha license changed while it was being reviewed; please start setup again." >&2
        exit 1
    fi
fi

license_accepted=0
if [[ "${license_downloaded}" -eq 1 && -f "${LICENSE_MARKER}" \
    && "$(<"${LICENSE_MARKER}")" == "${license_hash}" ]]; then
    license_accepted=1
fi

if [[ "${license_accepted}" -eq 0 ]]; then
    if [[ "${ACCEPT_EULA}" -eq 0 && ( ! -t 0 || ! -t 1 ) ]]; then
        if [[ "${license_downloaded}" -eq 1 ]]; then
            install -D -m644 "${tmpdir}/LICENSE-YAMAHA.html" "${STATE_DIR}/LICENSE-YAMAHA.html"
            echo "Yamaha's license was downloaded, but interactive acceptance is required." >&2
            echo "Review the license at ${STATE_DIR}/LICENSE-YAMAHA.html" >&2
        else
            echo "Yamaha's license could not be downloaded or did not contain the expected agreement." >&2
            echo "Please review it manually at: ${LICENSE_URL}" >&2
        fi
        echo "After reviewing and accepting Yamaha's terms, run:" >&2
        echo "  sudo ${0} --accept-eula" >&2
        exit 1
    fi
    if [[ "${ACCEPT_EULA}" -eq 1 ]]; then
        echo "Using explicit --accept-eula confirmation."
    else
        if [[ "${license_downloaded}" -eq 1 ]]; then
            echo "Yamaha AG DSP Controller license downloaded from:"
            echo "  ${LICENSE_URL}"
            echo "The downloaded license is shown below:"
            echo
            sed -e 's/<[^>]*>/ /g' \
                -e 's/&nbsp;/ /g' -e 's/&amp;/\&/g' \
                -e 's/&quot;/"/g' -e 's/&#39;/'"'"'/g' \
                "${tmpdir}/LICENSE-YAMAHA.html"
            echo
            read -r -p "Do you accept Yamaha's license terms? [y/N] " answer
        else
            echo "Yamaha's license page could not be downloaded or did not contain the expected agreement." >&2
            echo "Please review the license manually at: ${LICENSE_URL}" >&2
            read -r -p "Have you reviewed that page and do you agree to Yamaha's terms? [y/N] " answer
        fi
        case "${answer}" in
            y|Y|yes|YES) ;;
            *) echo "License not accepted; Yamaha software was not downloaded." >&2; exit 1 ;;
        esac
    fi
    if [[ "${license_downloaded}" -eq 1 ]]; then
        install -D -m644 "${tmpdir}/LICENSE-YAMAHA.html" "${STATE_DIR}/LICENSE-YAMAHA.html"
        printf '%s\n' "${license_hash}" | install -D -m644 /dev/stdin "${LICENSE_MARKER}"
    else
        printf '%s\n' manual-acceptance | install -D -m644 /dev/stdin "${LICENSE_MARKER}"
    fi
fi

# The controller archive is deliberately fetched only after license acceptance.
curl --fail --location --retry 3 --output "${tmpdir}/controller.zip" "${URL}"
echo "${SHA256}  ${tmpdir}/controller.zip" | sha256sum --check --status
unzip -q "${tmpdir}/controller.zip" -d "${tmpdir}/source"
SETUP="$(find "${tmpdir}/source" -type f -iname setup.exe -print -quit)"
[[ -n "${SETUP}" ]] || { echo "Yamaha archive did not contain setup.exe" >&2; exit 1; }

chown -R "${TARGET_UID}:${TARGET_GROUP}" "${tmpdir}"
run_as_user() {
    runuser --user "${TARGET_USER}" -- env \
        HOME="${TARGET_HOME}" USER="${TARGET_USER}" LOGNAME="${TARGET_USER}" \
        WINEPREFIX="${tmpdir}/wine-prefix" WINEDEBUG=-all \
        WINEDLLOVERRIDES='mscoree=d' \
        "${WINE_BIN}" "$@"
}
run_as_user_boot() {
    runuser --user "${TARGET_USER}" -- env \
        HOME="${TARGET_HOME}" USER="${TARGET_USER}" LOGNAME="${TARGET_USER}" \
        WINEPREFIX="${tmpdir}/wine-prefix" WINEDEBUG=-all \
        WINEDLLOVERRIDES='mscoree=d' "${WINE_BOOT_BIN}" "$@"
}
run_as_user_with_shim() {
    runuser --user "${TARGET_USER}" -- env \
        HOME="${TARGET_HOME}" USER="${TARGET_USER}" LOGNAME="${TARGET_USER}" \
        WINEPREFIX="${tmpdir}/wine-prefix" WINEDEBUG=-all \
        WINEDLLOVERRIDES='mscoree=d' \
        LD_PRELOAD="${DATA_DIR}/alsa-midi-name-shim.so${LD_PRELOAD:+:${LD_PRELOAD}}" \
        "${WINE_BIN}" "$@"
}

# Wine and Yamaha's Windows installer always run as the desktop user.
run_as_user_boot -u >/dev/null
run_as_user_with_shim "${SETUP}" /s /v/qn
EXE="$(find "${tmpdir}/wine-prefix/drive_c" -type f \
    -path '*/YAMAHA/AG DSP Controller/ag_dsp_controller.exe' -print -quit)"
[[ -n "${EXE}" ]] || { echo "Yamaha installer did not produce ag_dsp_controller.exe" >&2; exit 1; }

release_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
staged_release="${RELEASES_DIR}/.new-${release_id}"
release="${RELEASES_DIR}/${release_id}"
install -d -m755 "${staged_release}"
trap 'rm -rf -- "${tmpdir}" "${staged_release}"' EXIT
install -m644 "${EXE}" "${staged_release}/ag_dsp_controller.exe"
install -m644 "${DATA_DIR}/alsa-midi-name-shim.so" "${staged_release}/alsa-midi-name-shim.so"
find "$(dirname -- "${EXE}")" -maxdepth 1 -type f -name '*.csv' \
    -exec install -m644 {} "${staged_release}/" \;
chmod 644 "${staged_release}/ag_dsp_controller.exe"
test -s "${staged_release}/ag_dsp_controller.exe"

# Publish the complete release, then atomically switch the launcher's symlink.
mv -- "${staged_release}" "${release}"
ln -s "releases/${release_id}" "${DATA_DIR}/.current-${release_id}"
mv -Tf -- "${DATA_DIR}/.current-${release_id}" "${DATA_DIR}/current"
find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d \
    ! -name "${release_id}" ! -name ".new-${release_id}" -exec rm -rf -- {} +
echo "Yamaha AG DSP Controller installed atomically for ${TARGET_USER}."
