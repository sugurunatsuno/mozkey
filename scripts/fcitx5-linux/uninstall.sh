#!/usr/bin/env bash
# Removes files installed by install.sh.  User dictionaries and settings
# under ~/.mozc / ~/.config/mozc are left untouched.
#
# Usage:
#   sudo ./uninstall.sh
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "This script must be run as root: sudo ./uninstall.sh" >&2
  exit 1
fi

here=$(cd "$(dirname "$0")" && pwd)

addon_dir="${MOZKEY_FCITX5_ADDON_DIR:-}"
if [[ -z "${addon_dir}" ]] && command -v pkg-config >/dev/null 2>&1 \
    && pkg-config --exists Fcitx5Core 2>/dev/null; then
  addon_dir="$(pkg-config --variable=libdir Fcitx5Core)/fcitx5"
fi
if [[ -z "${addon_dir}" ]]; then
  for d in "/usr/lib/$(uname -m)-linux-gnu/fcitx5" /usr/lib64/fcitx5 \
      /usr/lib/fcitx5; do
    if [[ -f "${d}/fcitx5-mozc.so" ]]; then
      addon_dir="${d}"
      break
    fi
  done
fi

echo "==> Removing Mozkey files"
rm -f /usr/lib/mozkey/mozc_server /usr/lib/mozkey/mozc_tool \
  /usr/lib/mozkey/mozc_renderer
rmdir /usr/lib/mozkey 2>/dev/null || true
if [[ -n "${addon_dir}" ]]; then
  rm -f "${addon_dir}/fcitx5-mozc.so"
fi

# Remove everything this package staged under /usr/share, using the package
# content as the manifest.
(cd "${here}/share" && find . -type f -printf '%P\n') | while read -r f; do
  rm -f "/usr/share/${f}"
done

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -qf /usr/share/icons/hicolor || true
fi

echo "Done.  Restart fcitx5 to unload the addon.  Note: if you removed a"
echo "distro fcitx5-mozc package before installing Mozkey, reinstall it"
echo "with your package manager if you want plain Mozc back."
