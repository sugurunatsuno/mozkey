#!/usr/bin/env bash
# Installs Mozkey (fcitx5) from this package directory into the system.
#
# Usage:
#   sudo ./install.sh [--force]
#
# --force: proceed even if a distro fcitx5-mozc / mozc package is installed.
set -euo pipefail

force=0
if [[ "${1:-}" == "--force" ]]; then
  force=1
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "This script must be run as root: sudo ./install.sh" >&2
  exit 1
fi

here=$(cd "$(dirname "$0")" && pwd)

# Refuse to silently overwrite files owned by a distro package.  A later
# package upgrade would revert Mozkey back to plain Mozc.
conflict=""
if command -v dpkg >/dev/null 2>&1; then
  for p in fcitx5-mozc mozc-server mozc-utils-gui; do
    if dpkg -s "${p}" >/dev/null 2>&1; then
      conflict+=" ${p}"
    fi
  done
elif command -v rpm >/dev/null 2>&1; then
  for p in fcitx5-mozc mozc; do
    if rpm -q "${p}" >/dev/null 2>&1; then
      conflict+=" ${p}"
    fi
  done
elif command -v pacman >/dev/null 2>&1; then
  for p in fcitx5-mozc; do
    if pacman -Qi "${p}" >/dev/null 2>&1; then
      conflict+=" ${p}"
    fi
  done
fi
if [[ -n "${conflict}" && ${force} -eq 0 ]]; then
  echo "The following distro packages are installed:${conflict}" >&2
  echo "Mozkey would overwrite their files, and a future package upgrade" >&2
  echo "would overwrite Mozkey again.  Remove them first, e.g.:" >&2
  echo "  sudo apt remove${conflict}" >&2
  echo "or re-run with --force to overwrite anyway." >&2
  exit 1
fi

# Locate the fcitx5 addon directory.
addon_dir="${MOZKEY_FCITX5_ADDON_DIR:-}"
if [[ -z "${addon_dir}" ]] && command -v pkg-config >/dev/null 2>&1 \
    && pkg-config --exists Fcitx5Core 2>/dev/null; then
  addon_dir="$(pkg-config --variable=libdir Fcitx5Core)/fcitx5"
fi
if [[ -z "${addon_dir}" ]]; then
  for d in "/usr/lib/$(uname -m)-linux-gnu/fcitx5" /usr/lib64/fcitx5 \
      /usr/lib/fcitx5; do
    if [[ -d "${d}" ]]; then
      addon_dir="${d}"
      break
    fi
  done
fi
if [[ -z "${addon_dir}" ]]; then
  echo "Could not find the fcitx5 addon directory.  Is fcitx5 installed?" >&2
  echo "Set MOZKEY_FCITX5_ADDON_DIR=/path/to/fcitx5 and retry." >&2
  exit 1
fi

echo "==> Installing binaries to /usr/lib/mozkey"
install -D -m 755 "${here}/lib/mozkey/mozc_server" /usr/lib/mozkey/mozc_server
install -D -m 755 "${here}/lib/mozkey/mozc_tool" /usr/lib/mozkey/mozc_tool
install -D -m 755 "${here}/lib/mozkey/mozc_renderer" /usr/lib/mozkey/mozc_renderer

echo "==> Installing fcitx5 addon to ${addon_dir}"
install -D -m 644 "${here}/lib/fcitx5/fcitx5-mozc.so" \
  "${addon_dir}/fcitx5-mozc.so"

echo "==> Installing configuration, icons and translations to /usr/share"
(cd "${here}/share" && find . -type f -printf '%P\n') | while read -r f; do
  install -D -m 644 "${here}/share/${f}" "/usr/share/${f}"
done

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -qf /usr/share/icons/hicolor || true
fi

echo
echo "Mozkey has been installed."
echo "Next steps:"
echo "  1. Restart fcitx5:        fcitx5 -rd >/dev/null 2>&1 &"
echo "  2. Add \"Mozc\" as an input method (fcitx5-configtool)."
echo "  3. If an old mozc_server is still running, stop it so the new one"
echo "     starts on the next conversion:  pkill -f /usr/lib/mozkey/mozc_server"
