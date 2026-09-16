# Yamaha AG DSP Controller on Linux

This project runs Yamaha's Windows **AG DSP Controller** for the original
Yamaha AG06 and AG03 mixers through Wine on Linux. It includes a small
project-owned MIDI-name compatibility shim for Wine's ALSA MIDI device name.

Supported devices:

- Yamaha AG06
- Yamaha AG03

This is not intended for the AG06MK2, AG03MK2, or AG01.

## How it works

The project does not redistribute Yamaha's Windows executable. The packaged
installer downloads Yamaha's official controller archive only after the user
accepts Yamaha's current license terms. It verifies the archive with its
recorded SHA-256 checksum, installs the Windows application into a temporary
Wine prefix with the project-owned shim, and stores the unmodified executable
and preset data in the system data directory.

The Yamaha Steinberg USB driver is not installed. Linux provides the AG06/AG03
USB audio and MIDI interfaces through ALSA and the normal Linux audio stack.
The launcher does not depend on a particular USB bus, device number, or
physical USB port. The runtime discovers the device through Linux's audio and
MIDI interfaces.

## Install from a DEB or RPM package

Prebuilt DEB and RPM packages are produced by the GitHub release workflow.
They contain the Linux launcher and installer helper; they do not contain
Yamaha's executable, ZIP archive, or EULA.

After installing the package, setup is deferred until the first launch. The
launcher downloads and validates Yamaha's EULA page, shows the license for
interactive acceptance, and downloads the controller only after acceptance.

If the package manager has no interactive terminal, the package itself remains
installed but the Yamaha component is left uninstalled. The package output
provides this recovery command:

```bash
sudo /usr/libexec/ag-dsp-controller-install --accept-eula
```

Use `--accept-eula` only after reviewing Yamaha's terms. The option is an
explicit noninteractive confirmation; it does not suppress the EULA download
or the controller archive checksum verification.

The desktop entry can also complete setup. When `zenity`, `pkexec`, and a
graphical session are available, launching **AG DSP Controller** downloads the
current EULA, displays it in a window, asks for acceptance, and opens the graphical
authorization prompt. Without those optional tools, it prints the command
above instead; if `notify-send` is available, it also displays a desktop
notification explaining what to run.

The installer records the accepted EULA hash in `/var/lib/ag-dsp-controller`.
It does not display the license every time the controller starts. If the
installer is run again after Yamaha changes the downloaded EULA, it asks for
acceptance again before proceeding.

## Install directly from a source checkout on Fedora

This path is useful for local development and does not install a system
package or desktop entry. It builds the project-owned MIDI shim,
downloads Yamaha's official archive into the checkout, installs it in a
temporary Wine prefix, and leaves the unmodified executable and runtime files
in the checkout.

Install the prerequisites:

```bash
sudo dnf install curl unzip wine gcc
```

Run the installer and launch the controller:

```bash
./install-fedora.sh
./ag-dsp-controller
```

The standalone script currently downloads the official Yamaha archive directly
and is separate from the package installer's EULA workflow. Review Yamaha's
terms before using this path. The downloaded archive, generated executable,
preset CSVs, Wine prefixes, and other runtime files are ignored by Git.

## Device diagnostics

Connect the mixer directly by USB and power it on. To inspect the ALSA MIDI
and audio device discovery, run:

```bash
./check-device.sh
```

For the complete diagnostic output, install `alsa-utils` for `amidi` and a
desktop audio utility providing `pactl`. The expected MIDI name under Wine is:

```text
AG06/AG03 - AG06/AG03 MIDI 1
```

The launcher changes this Wine-generated name to `AG06/AG03` with its shim.

If the device is visible but the controller cannot find it, run the suggested
Wine MIDI diagnostic command printed by `check-device.sh`.

## Runtime state and files

For a packaged installation:

| Path | Purpose |
| --- | --- |
| `/usr/bin/ag-dsp-controller` | User-facing launcher |
| `/usr/share/ag-dsp-controller/current/` | Active unmodified executable, preset data, and shim |
| `/usr/share/ag-dsp-controller/releases/` | Versioned installed releases |
| `/usr/libexec/ag-dsp-controller-install` | Root installer helper |
| `/var/lib/ag-dsp-controller/` | Accepted EULA hash and downloaded license copy |
| `~/.local/share/ag-dsp-controller/wine-prefix/` | Per-user writable Wine state |

`XDG_DATA_HOME` can change the per-user Wine state location. `WINEPREFIX` and
`WINE_BIN` can also be overridden when launching the controller.

The package's system files are shared, while Wine's writable state is kept per
user so normal operation does not require root privileges.

### Verifying release packages

Each GitHub release includes detached GPG signatures for the DEB and RPM, plus
the public key used to create them. Verify the key fingerprint before importing
it; the current release key fingerprint is:

```text
EDA7 A7B2 7EF6 9B15 9FD4 382D F143 A790 A52B 70B9
```

For a release tagged `v1.0.1`, choose the complete instructions for your
distribution.

### Fedora

```bash
curl --fail --location --remote-name \
  https://github.com/DejfCold/ag-dsp-controller/releases/download/v1.0.1/ag-dsp-controller-signing-key.asc &&
gpg --show-keys --with-fingerprint ag-dsp-controller-signing-key.asc &&
gpg --show-keys --with-colons ag-dsp-controller-signing-key.asc \
  | grep -Fq 'EDA7A7B27EF69B159FD4382DF143A790A52B70B9' &&
sudo rpm --import ag-dsp-controller-signing-key.asc &&
sudo dnf install \
  https://github.com/DejfCold/ag-dsp-controller/releases/download/v1.0.1/ag-dsp-controller-1.0.1-1.x86_64.rpm
```

The RPM carries a native RPM signature, so `rpm --import` makes the key
available to RPM and DNF verifies the package before installing it. If you
prefer to inspect the file first, download it and run `rpm --checksig --verbose`
before installing it with `dnf`.

### Debian or Ubuntu

Download the public key and the matching DEB plus its detached signature:

```bash
curl --fail --location --remote-name \
  https://github.com/DejfCold/ag-dsp-controller/releases/download/v1.0.1/ag-dsp-controller-signing-key.asc &&
gpg --show-keys --with-fingerprint ag-dsp-controller-signing-key.asc &&
gpg --show-keys --with-colons ag-dsp-controller-signing-key.asc \
  | grep -Fq 'EDA7A7B27EF69B159FD4382DF143A790A52B70B9' &&
gpg --import ag-dsp-controller-signing-key.asc &&
curl --fail --location --remote-name \
  https://github.com/DejfCold/ag-dsp-controller/releases/download/v1.0.1/ag-dsp-controller_1.0.1-1_amd64.deb &&
curl --fail --location --remote-name \
  https://github.com/DejfCold/ag-dsp-controller/releases/download/v1.0.1/ag-dsp-controller_1.0.1-1_amd64.deb.asc &&
gpg --verify ag-dsp-controller_1.0.1-1_amd64.deb.asc \
  ag-dsp-controller_1.0.1-1_amd64.deb &&
sudo apt install ./ag-dsp-controller_1.0.1-1_amd64.deb
```

The DEB signature is detached because APT does not use a detached signature
when installing a standalone local package. `gpg --verify` must succeed before
running `apt install`.

To remove a packaged installation, use the bundled uninstaller:

```bash
sudo /usr/libexec/ag-dsp-controller-uninstall
```

It asks for confirmation, removes the downloaded Yamaha executable, preset
data, and installer/EULA state, and then runs the detected package manager to
remove the package. The per-user Wine prefix is preserved by default. To
remove that too for the invoking user, use:

```bash
sudo /usr/libexec/ag-dsp-controller-uninstall --remove-user-state
```

Add `--yes` to skip the uninstaller and package-manager confirmations.

## Build DEB and RPM packages

Package builds do not download or execute the Yamaha installer. They stage the
launcher, helper, desktop entry, and shim; Yamaha's binary and EULA are fetched
later on the target machine during setup.

On Fedora, install the RPM build tools:

```bash
sudo dnf install rpm-build gcc
```

On Ubuntu or Debian:

```bash
sudo apt install debhelper devscripts build-essential rpm
```

Build each package with its native tool: `dpkg-buildpackage --build=binary
--no-sign` for DEB, or `rpmbuild -bb rpm/ag-dsp-controller.spec`
after compiling and staging the shim and source files:

```bash
mkdir -p .rpmbuild/{SOURCES,SPECS,tmp}
gcc -Wall -Wextra -Werror -shared -fPIC -O2 \
  alsa-midi-name-shim.c -o alsa-midi-name-shim.so -ldl
cp ag-dsp-controller.sh ag-dsp-controller.desktop .rpmbuild/SOURCES/
cp install-yamaha-controller.sh uninstall-ag-dsp-controller.sh .rpmbuild/SOURCES/
cp LICENSE THIRD_PARTY_NOTICES alsa-midi-name-shim.so .rpmbuild/SOURCES/
cp rpm/ag-dsp-controller.spec .rpmbuild/SPECS/
rpmbuild -bb .rpmbuild/SPECS/ag-dsp-controller.spec \
  --define "_topdir $PWD/.rpmbuild"
```

The GitHub Actions workflow performs this staging in a clean checkout.

The GitHub Actions workflow performs the same package-only build on Ubuntu
24.04. A tag such as `v1.0.1` creates a GitHub release and attaches the DEB
and RPM artifacts. The workflow does not fetch Yamaha's binary; installation
on the user's machine does that after license acceptance.

For maintainers, tagged-release signing is enabled by the `GPG_PRIVATE_KEY`
GitHub Actions secret. Set that secret to the contents of the armored private
key generated for this project. Never commit or publish that private key. The
workflow derives the public key, signs each package with a detached armored
signature, and publishes the public key alongside the release assets.

## MIDI compatibility

The unmodified Yamaha executable is run with the project-owned ALSA
shim. It narrows Wine's generated MIDI client name and presents the AG06/AG03
port under the short name expected by the controller. The shim changes neither
MIDI messages nor Yamaha's executable.

The compatibility approach is based on the original implementation by Dale
Whinham in his AG DSP Controller patch. This repository does not redistribute
that patch; its shim is maintained as independent project code.

Development of this repository was aided by **GPT-5.6-Luna Medium**, an
OpenAI Codex assistant based on GPT-5.

Yamaha's controller and license remain Yamaha property. This repository only
provides the Linux packaging, launcher, shim, and installer integration.

## License

The original work in this repository is released under the WTFPL v2; see
`LICENSE`. That license does not apply to Yamaha's controller or Yamaha's EULA.
