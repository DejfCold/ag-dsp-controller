#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d -t ag-dsp-controller-tests.XXXXXX)"
trap 'rm -rf -- "${TEST_DIR}"' EXIT
cd "${ROOT_DIR}"

for script in ag-dsp-controller.sh check-device.sh install-fedora.sh \
    install-yamaha-controller.sh uninstall-ag-dsp-controller.sh \
    debian/rules debian/postinst; do
    bash -n "${script}"
done

grep -Eq 'gcc .* -shared' install-fedora.sh
! grep -Fq 'wine32' debian/control
! grep -RInE 'wine32|wine\.i686|gcc-multilib|libc6-dev-i386|m32|i386' README.md ag-dsp-controller.sh install-fedora.sh debian .github
grep -Fq 'alsa-midi-name-shim.c' debian/rules
grep -Fq 'command -v wine' install-yamaha-controller.sh
! grep -Fq 'wine.i686' rpm/ag-dsp-controller.spec
grep -Fq 'strcmp(name, "AG06/AG03")' alsa-midi-name-shim.c
! grep -Fq 'strncmp(name, "AG06/AG03"' alsa-midi-name-shim.c
! grep -RInE 'build-packages|fix-midi-device-name|AUR patch|patched executable' README.md .github debian

if command -v rpmspec >/dev/null 2>&1; then
    rpmspec -P rpm/ag-dsp-controller.spec >/dev/null
fi

# Missing installation helper must fail before Wine is invoked.
missing_data="${TEST_DIR}/missing-data"
mkdir -p "${missing_data}"
set +e
missing_output="$(AG06_DATA_DIR="${missing_data}" \
    AG06_INSTALLER="${TEST_DIR}/missing-installer" WINE_BIN=/bin/false WINE_BOOT_BIN=/bin/false \
    HOME="${TEST_DIR}/home" "${ROOT_DIR}/ag-dsp-controller.sh" 2>&1)"
missing_status=$?
set -e
[[ "${missing_status}" -ne 0 ]]
grep -Fq 'AG DSP Controller is not installed yet.' <<<"${missing_output}"

# Two simultaneous launches must initialize one shared prefix only once.
prefix_data="${TEST_DIR}/prefix-data"
prefix="${TEST_DIR}/prefix"
mkdir -p "${prefix_data}"
printf executable >"${prefix_data}/ag_dsp_controller.exe"
printf 'void test_shim(void) {}\n' | gcc -shared -fPIC -x c - -o "${prefix_data}/alsa-midi-name-shim.so"
cat >"${TEST_DIR}/fake-wine" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == -u ]]; then
    printf 'wineboot\n' >>"${TEST_WINE_LOG}"
    sleep 0.2
    mkdir -p "${WINEPREFIX}/drive_c"
fi
EOF
chmod 755 "${TEST_DIR}/fake-wine"
: >"${TEST_DIR}/wine.log"
(WINE_BIN="${TEST_DIR}/fake-wine" WINE_BOOT_BIN="${TEST_DIR}/fake-wine" WINEPREFIX="${prefix}" TEST_WINE_LOG="${TEST_DIR}/wine.log" \
    AG06_DATA_DIR="${prefix_data}" "${ROOT_DIR}/ag-dsp-controller.sh") & first=$!
(WINE_BIN="${TEST_DIR}/fake-wine" WINE_BOOT_BIN="${TEST_DIR}/fake-wine" WINEPREFIX="${prefix}" TEST_WINE_LOG="${TEST_DIR}/wine.log" \
    AG06_DATA_DIR="${prefix_data}" "${ROOT_DIR}/ag-dsp-controller.sh") & second=$!
wait "${first}"; wait "${second}"
[[ "$(grep -c '^wineboot$' "${TEST_DIR}/wine.log")" -eq 1 ]]

echo "Packaging and launcher regression checks passed."
