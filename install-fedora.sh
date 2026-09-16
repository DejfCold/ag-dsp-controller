#!/usr/bin/env bash
set -euo pipefail

AG06_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${AG06_DIR}"
[[ "${EUID}" -ne 0 ]] || { echo "Do not run as root; Wine must run as your desktop user." >&2; exit 1; }

ZIP="AG_DSP_Controller_v1100_win.zip"
URL="https://usa.yamaha.com/files/download/software/6/827126/${ZIP}"
SHA256="2b2a7af814be568bf65885b9514b492565cdf0a9d42d0620ffe7ab24069de117"
PREFIX="${AG06_DIR}/build-wine-prefix"
EXTRACT="${AG06_DIR}/yamaha-installer"
RELEASES_DIR="${AG06_DIR}/releases"
SHIM="${AG06_DIR}/alsa-midi-name-shim.so"

for tool in curl unzip wine wineboot gcc; do
    command -v "${tool}" >/dev/null || { echo "Missing ${tool}; install curl unzip wine gcc." >&2; exit 1; }
done
echo "Building the Wine ALSA MIDI name shim..."
gcc -Wall -Wextra -Werror -shared -fPIC -O2 alsa-midi-name-shim.c -o "${SHIM}" -ldl

if [[ ! -f "${ZIP}" ]]; then
    curl --fail --location --retry 3 --output "${ZIP}.part" "${URL}"
    echo "${SHA256}  ${ZIP}.part" | sha256sum --check --status
    mv -- "${ZIP}.part" "${ZIP}"
fi
echo "${SHA256}  ${ZIP}" | sha256sum --check --status
rm -rf -- "${EXTRACT}" "${PREFIX}"
mkdir -p "${EXTRACT}" "${RELEASES_DIR}"
unzip -q "${ZIP}" -d "${EXTRACT}"
SETUP="$(find "${EXTRACT}" -type f -iname setup.exe -print -quit)"
[[ -n "${SETUP}" ]] || { echo "Could not find setup.exe in ${ZIP}" >&2; exit 1; }

export WINEPREFIX="${PREFIX}" WINEDEBUG=-all WINEDLLOVERRIDES='mscoree=d'
wineboot -u >/dev/null
LD_PRELOAD="${SHIM}${LD_PRELOAD:+:${LD_PRELOAD}}" wine "${SETUP}" /s /v/qn
EXE="$(find "${PREFIX}/drive_c" -type f -path '*/YAMAHA/AG DSP Controller/ag_dsp_controller.exe' -print -quit)"
[[ -n "${EXE}" ]] || { echo "Yamaha installer did not produce the expected executable." >&2; exit 1; }

release_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
staged="${RELEASES_DIR}/.new-${release_id}"
release="${RELEASES_DIR}/${release_id}"
install -d -m755 "${staged}"
install -m644 "${EXE}" "${staged}/ag_dsp_controller.exe"
install -m644 "${SHIM}" "${staged}/alsa-midi-name-shim.so"
find "$(dirname -- "${EXE}")" -maxdepth 1 -type f -name '*.csv' -exec install -m644 {} "${staged}/" \;
mv -- "${staged}" "${release}"
ln -s "releases/${release_id}" "${AG06_DIR}/.current-${release_id}"
mv -Tf -- "${AG06_DIR}/.current-${release_id}" "${AG06_DIR}/current"
find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d ! -name "${release_id}" -exec rm -rf -- {} +
cp -- "${AG06_DIR}/ag-dsp-controller.sh" "${AG06_DIR}/ag-dsp-controller"
chmod +x "${AG06_DIR}/ag-dsp-controller"
rm -rf -- "${EXTRACT}" "${PREFIX}"
echo "Installed in ${AG06_DIR}. Run: ${AG06_DIR}/ag-dsp-controller"
