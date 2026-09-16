#!/usr/bin/env bash
set -euo pipefail

# The executable and Yamaha data are shared by the package, while Wine's
# writable state belongs to the user. AG06_DATA_DIR also supports source use.
AG06_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${AG06_DATA_DIR:-}" && "${AG06_DIR}" == "/usr/bin" \
    && -d "/usr/share/ag-dsp-controller" ]]; then
    AG06_DATA_DIR="/usr/share/ag-dsp-controller/current"
elif [[ -z "${AG06_DATA_DIR:-}" && ( -L "${AG06_DIR}/current" || -d "${AG06_DIR}/current" ) ]]; then
    AG06_DATA_DIR="${AG06_DIR}/current"
else
    AG06_DATA_DIR="${AG06_DATA_DIR:-${AG06_DIR}}"
fi
AG06_STATE_DIR="${AG06_STATE_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/ag-dsp-controller}"
export WINEPREFIX="${WINEPREFIX:-${AG06_STATE_DIR}/wine-prefix}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree=d}"
WINE_BIN="${WINE_BIN:-$(command -v wine || true)}"
if [[ -z "${WINE_BIN}" ]]; then
    echo "Wine is missing. Install the normal Wine runtime package." >&2
    exit 1
fi
WINE_BOOT_BIN="${WINE_BOOT_BIN:-$(command -v wineboot || true)}"
if [[ -z "${WINE_BOOT_BIN}" ]]; then
    echo "Wine prefix initialization is unavailable. Install Wine's wineboot command." >&2
    exit 1
fi

if [[ ! -f "${AG06_DATA_DIR}/ag_dsp_controller.exe" ]]; then
    INSTALLER="${AG06_INSTALLER:-/usr/libexec/ag-dsp-controller-install}"
    if [[ -x "${INSTALLER}" ]]; then
        if command -v zenity >/dev/null 2>&1 && command -v pkexec >/dev/null 2>&1 \
            && command -v curl >/dev/null 2>&1 \
            && command -v python3 >/dev/null 2>&1 \
            && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
            accepted=0
            license_url="https://usa.yamaha.com/support/updates/ag_dsp_win.html"
            license_download="$(mktemp -t ag-dsp-controller-license.XXXXXX)"
            license_view="$(mktemp -t ag-dsp-controller-license-view.XXXXXX.txt)"
            license_hash=""
            if curl --silent --show-error --fail --location --retry 3 \
                --output "${license_download}" "${license_url}" \
                && grep -Fq "PLEASE READ THIS SOFTWARE LICENSE AGREEMENT" "${license_download}" \
                && grep -Fq "AG DSP Controller" "${license_download}"; then
                license_hash="$(sha256sum "${license_download}" | awk '{print $1}')"
                # Keep the downloaded document byte-for-byte intact for the
                # hash check, but extract only the EULA section for review.
                # HTMLParser tolerates attribute ordering/whitespace and
                # nested markup; failure is safer than showing an empty view.
                if python3 - "${license_download}" "${license_view}" <<'PY'
import sys
from html.parser import HTMLParser

class LicenseParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.parts = []
        self.found = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if not self.found and tag.lower() == "div":
            classes = set((attrs.get("class") or "").split())
            if "license-agreement" in classes:
                self.found = True
                self.depth = 1
                return
        if self.found:
            if tag.lower() in {"br", "p", "div", "h1", "h2", "h3", "h4", "li"}:
                self.parts.append("\n")
            if tag.lower() not in {"br", "meta", "link", "img", "input", "hr"}:
                self.depth += 1

    def handle_startendtag(self, tag, attrs):
        if self.found and tag.lower() == "br":
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if self.found:
            if tag.lower() in {"p", "div", "h1", "h2", "h3", "h4", "li"}:
                self.parts.append("\n")
            if tag.lower() not in {"br", "meta", "link", "img", "input", "hr"}:
                self.depth -= 1
                if self.depth == 0:
                    self.found = False

    def handle_data(self, data):
        if self.found:
            self.parts.append(data)

source, destination = sys.argv[1:]
parser = LicenseParser()
with open(source, encoding="utf-8", errors="replace") as stream:
    parser.feed(stream.read())
text = " ".join(" ".join(parser.parts).split())
if len(text) < 200:
    raise SystemExit("license agreement section was not extracted")
with open(destination, "w", encoding="utf-8") as stream:
    stream.write("Yamaha AG DSP Controller license\n\n" + text + "\n")
PY
                    then
                    if zenity --text-info --filename="${license_view}" \
                        --title="Yamaha AG DSP Controller license" \
                        --checkbox="I have read the Yamaha AG DSP Controller license" \
                        --ok-label="Accept" --cancel-label="Decline"; then
                        accepted=1
                    fi
                else
                    zenity --error --title="Yamaha AG DSP Controller" \
                        --text="The downloaded license could not be extracted for review. Setup is cancelled." || true
                fi
            else
                zenity --error --title="Yamaha AG DSP Controller" \
                    --text="Yamaha's current license could not be downloaded. Review it manually at:\n${license_url}" || true
            fi
            if [[ "${accepted}" -eq 1 ]]; then
                installer_log="$(mktemp -t ag-dsp-controller-install.XXXXXX)"
                if pkexec "${INSTALLER}" --accept-eula \
                    "--expected-license-hash=${license_hash}" \
                    "--license-file=${license_download}" >"${installer_log}" 2>&1; then
                    :
                else
                    details="$(tail -n 16 "${installer_log}")"
                    error_text=$'The Yamaha controller could not be installed.\n\n'"${details}"
                    zenity --error --title="AG DSP Controller installation failed" \
                        --no-markup \
                        --text="${error_text}" || true
                fi
                rm -f -- "${installer_log}"
            fi
            rm -f -- "${license_download}" "${license_view}"
            if [[ "${accepted}" -eq 1 && -f "${AG06_DATA_DIR}/ag_dsp_controller.exe" ]]; then
                :
            else
                exit 1
            fi
        else
            echo "AG DSP Controller is not installed yet." >&2
            message="AG DSP Controller is not installed yet.\n\nReview Yamaha's terms, then run:\n sudo ${INSTALLER} --accept-eula"
            if command -v notify-send >/dev/null 2>&1 \
                && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
                notify-send --urgency=critical "AG DSP Controller setup required" "${message}"
            fi
            echo "Run: sudo ${INSTALLER} --accept-eula" >&2
            exit 1
        fi
    else
        echo "AG DSP Controller is not installed yet." >&2
        if command -v notify-send >/dev/null 2>&1 \
            && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
            notify-send --urgency=critical "AG DSP Controller setup required" \
                "Run sudo ${INSTALLER:-/usr/libexec/ag-dsp-controller-install} --accept-eula"
        fi
        echo "Run ./install-fedora.sh first." >&2
        exit 1
    fi
fi

if [[ ! -s "${AG06_DATA_DIR}/alsa-midi-name-shim.so" ]]; then
    echo "The Wine ALSA MIDI name shim is missing from ${AG06_DATA_DIR}." >&2
    exit 1
fi

WINEPREFIX_PARENT="$(dirname -- "${WINEPREFIX}")"
mkdir -p "${WINEPREFIX_PARENT}"
exec 8>"${WINEPREFIX}.lock"
flock 8
if [[ ! -d "${WINEPREFIX}" ]]; then
    mkdir -p "${WINEPREFIX}"
    "${WINE_BOOT_BIN}" -u >/dev/null
fi
flock -u 8
exec 8>&-

cd -- "${AG06_DATA_DIR}"
if [[ -n "${LD_PRELOAD:-}" ]]; then
    export LD_PRELOAD="${AG06_DATA_DIR}/alsa-midi-name-shim.so:${LD_PRELOAD}"
else
    export LD_PRELOAD="${AG06_DATA_DIR}/alsa-midi-name-shim.so"
fi
exec "${WINE_BIN}" "${AG06_DATA_DIR}/ag_dsp_controller.exe" "$@"
