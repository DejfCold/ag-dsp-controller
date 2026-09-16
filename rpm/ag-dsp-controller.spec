Name:           ag-dsp-controller
%global pkgver  1.0.0
Version:        %{pkgver}
Release:        1%{?dist}
Summary:        Yamaha AG06/AG03 DSP Controller installer for Linux
License:        WTFPL
URL:            https://github.com/DejfCold/ag-dsp-controller
BuildArch:      x86_64
Requires:       wine
Requires:       curl
Requires:       unzip
Requires:       util-linux
Recommends:     zenity
Recommends:     polkit
Recommends:     python3
Source0:        ag-dsp-controller.sh
Source1:        ag-dsp-controller.desktop
Source2:        install-yamaha-controller.sh
Source3:        uninstall-ag-dsp-controller.sh
Source4:        LICENSE
Source5:        THIRD_PARTY_NOTICES
Source6:        alsa-midi-name-shim.so

%description
Downloads Yamaha's AG06/AG03 DSP Controller after interactive acceptance of
Yamaha's current license terms, then runs it through Wine and ALSA MIDI.

%prep

%build

%install
install -D -m755 %{SOURCE0} %{buildroot}%{_bindir}/ag-dsp-controller
install -D -m644 %{SOURCE1} %{buildroot}%{_datadir}/applications/ag-dsp-controller.desktop
install -D -m755 %{SOURCE2} %{buildroot}%{_libexecdir}/ag-dsp-controller-install
install -D -m755 %{SOURCE3} %{buildroot}%{_libexecdir}/ag-dsp-controller-uninstall
install -D -m644 %{SOURCE4} %{buildroot}%{_licensedir}/%{name}/LICENSE
install -D -m644 %{SOURCE5} %{buildroot}%{_docdir}/%{name}/THIRD_PARTY_NOTICES
install -D -m644 %{SOURCE6} %{buildroot}%{_datadir}/ag-dsp-controller/alsa-midi-name-shim.so
install -d -m755 %{buildroot}%{_datadir}/ag-dsp-controller

%post
if [ "$1" -ge 1 ]; then
    echo "AG DSP Controller setup is deferred until first launch."
    echo "Launch 'AG DSP Controller' to review Yamaha's license and install it."
fi

%files
%{_bindir}/ag-dsp-controller
%{_libexecdir}/ag-dsp-controller-install
%{_libexecdir}/ag-dsp-controller-uninstall
%{_datadir}/applications/ag-dsp-controller.desktop
%dir %{_datadir}/ag-dsp-controller
%{_datadir}/ag-dsp-controller/alsa-midi-name-shim.so
%license %{_licensedir}/%{name}/LICENSE
%doc %{_docdir}/%{name}/THIRD_PARTY_NOTICES

%changelog
* Wed Sep 16 2026 DejfCold <dejfcold@dejfcold.cz> - 1.0.0-1
- Add native RPM packaging and deferred Yamaha setup.
