#!/usr/bin/env bash
set -u
AG06_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo 'ALSA MIDI ports:'
if command -v amidi >/dev/null; then
    amidi -l || true
else
    echo '  amidi is not installed (Fedora package: alsa-utils)'
fi

echo
echo 'USB audio devices:'
if command -v pactl >/dev/null; then
    pactl list short cards 2>/dev/null | rg -i 'AG06|AG03|Yamaha' || echo '  no Yamaha AG card found'
else
    echo '  pactl is not installed'
fi

echo
echo 'Expected MIDI name under Wine with the shim: AG06/AG03'
echo 'If the AG06 appears above but the controller cannot connect, run:'
echo "  WINEPREFIX=\"${AG06_DIR}/wine-prefix\" WINEDEBUG=+midi ${AG06_DIR}/ag-dsp-controller"
