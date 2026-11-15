# Showtime Suite downloads

Installers of [Showtime Suite](https://github.com/Cheter0410/showtime-suite) (formerly Stagehand) are under **Releases**
(macOS `.dmg`, Windows `Showtime-Suite-Setup-….exe`, Linux `…-linux-x86_64.tar.gz`).

`apps.json` is the live catalog: Showtime Suite reads it on start, so an app added here appears in every
installed Showtime Suite without a new version. Format: see the Showtime Suite README ("Adding an app").

## Ohne Internet (USB-Stick, Linux)

Lade die Linux-Dateien der Apps (`*-linux-x86_64.tar.gz`, für Show Master auch
das Arch-Paket `*.pkg.tar.zst`) und [`usb-install.sh`](usb-install.sh) auf den
Stick. Auf dem Rechner dann:

    sh /run/media/$USER/<Stick>/usb-install.sh
