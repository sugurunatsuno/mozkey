#!/usr/bin/env bash
# Builds a distributable tarball of Mozkey for Linux + fcitx5.
#
# Usage:
#   scripts/fcitx5-linux/build_package.sh
#
# Output:
#   dist/linux/mozkey-fcitx5-<version>-<arch>.tar.gz
#
# The tarball contains mozc_server / mozc_tool / mozc_renderer /
# fcitx5-mozc.so, fcitx5 addon configuration, icons, translations and
# install.sh / uninstall.sh.  See docs/build_fcitx5_for_linux.md.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "${script_dir}/../.." && pwd)
src_dir="${repo_root}/src"

# Prefer bazelisk (respects src/.bazeliskrc); fall back to bazel.
if [[ -z "${BAZEL:-}" ]]; then
  if command -v bazelisk >/dev/null 2>&1; then
    BAZEL=bazelisk
  else
    BAZEL=bazel
  fi
fi

targets=(
  //server:mozc_server
  //gui/tool:mozc_tool
  //renderer/qt:mozc_renderer
  //unix/fcitx5:fcitx5-mozc.so
  //unix:icons
)

echo "==> Building release binaries with ${BAZEL} ..."
(cd "${src_dir}" && "${BAZEL}" build --config release_build "${targets[@]}")

bazel_bin="${src_dir}/bazel-bin"

ver() {
  sed -n "s/^$1 = \([0-9][0-9]*\).*/\1/p" "${src_dir}/version.bzl"
}
version="$(ver MOZKEY_RELEASE_VERSION_MAJOR).$(ver MOZKEY_RELEASE_VERSION_MINOR).$(ver MOZKEY_RELEASE_VERSION_PATCH)"
arch=$(uname -m)
pkg_name="mozkey-fcitx5-${version}-${arch}"

out_dir="${repo_root}/dist/linux"
stage="${out_dir}/${pkg_name}"
rm -rf "${stage}"
mkdir -p "${stage}"

echo "==> Staging ${pkg_name} ..."

# Binaries.
install -D -m 755 "${bazel_bin}/server/mozc_server" "${stage}/lib/mozkey/mozc_server"
install -D -m 755 "${bazel_bin}/gui/tool/mozc_tool" "${stage}/lib/mozkey/mozc_tool"
install -D -m 755 "${bazel_bin}/renderer/qt/mozc_renderer" "${stage}/lib/mozkey/mozc_renderer"
install -D -m 644 "${bazel_bin}/unix/fcitx5/fcitx5-mozc.so" "${stage}/lib/fcitx5/fcitx5-mozc.so"

if command -v strip >/dev/null 2>&1; then
  strip "${stage}/lib/mozkey/mozc_server" "${stage}/lib/mozkey/mozc_tool" \
    "${stage}/lib/mozkey/mozc_renderer"
  strip --strip-unneeded "${stage}/lib/fcitx5/fcitx5-mozc.so"
fi

# fcitx5 addon / input method configuration.
install -D -m 644 "${src_dir}/unix/fcitx5/mozc-addon.conf" \
  "${stage}/share/fcitx5/addon/mozc.conf"
install -D -m 644 "${src_dir}/unix/fcitx5/mozc.conf" \
  "${stage}/share/fcitx5/inputmethod/mozc.conf"

# Icons.  unix:icons produces a flat zip; rename entries to the icon names
# that unix/fcitx5/mozc_engine.cc refers to (fcitx_mozc_*), and duplicate
# them with the org.fcitx.Fcitx5. prefix used by fcitx5's icon lookup.
icons_tmp=$(mktemp -d)
trap 'rm -rf "${icons_tmp}"' EXIT
python3 -m zipfile -e "${bazel_bin}/unix/icons.zip" "${icons_tmp}"

install_icon() {
  local src="$1" size="$2" name="$3"
  local dir="${stage}/share/icons/hicolor/${size}/apps"
  if [[ ! -f "${icons_tmp}/${src}" ]]; then
    echo "WARNING: icon ${src} not found in icons.zip; skipping" >&2
    return 0
  fi
  install -D -m 644 "${icons_tmp}/${src}" "${dir}/${name}.png"
  install -D -m 644 "${icons_tmp}/${src}" "${dir}/org.fcitx.Fcitx5.${name}.png"
}

install_icon mozc.png           128x128 fcitx_mozc
install_icon direct.png         48x48   fcitx_mozc_direct
install_icon hiragana.png       48x48   fcitx_mozc_hiragana
install_icon katakana_full.png  48x48   fcitx_mozc_katakana_full
install_icon katakana_half.png  48x48   fcitx_mozc_katakana_half
install_icon alpha_full.png     48x48   fcitx_mozc_alpha_full
install_icon alpha_half.png     48x48   fcitx_mozc_alpha_half
install_icon dictionary.png     48x48   fcitx_mozc_dictionary
install_icon properties.png     48x48   fcitx_mozc_properties
install_icon tool.png           48x48   fcitx_mozc_tool

# Translations.
if command -v msgfmt >/dev/null 2>&1; then
  while read -r lang; do
    [[ -z "${lang}" ]] && continue
    po="${src_dir}/unix/fcitx5/po/${lang}.po"
    [[ -f "${po}" ]] || continue
    mo_dir="${stage}/share/locale/${lang}/LC_MESSAGES"
    mkdir -p "${mo_dir}"
    msgfmt "${po}" -o "${mo_dir}/fcitx5-mozc.mo"
  done < "${src_dir}/unix/fcitx5/po/LINGUAS"
else
  echo "WARNING: msgfmt (gettext) not found; skipping translations" >&2
fi

# Installer scripts and package notes.
install -m 755 "${script_dir}/install.sh" "${stage}/install.sh"
install -m 755 "${script_dir}/uninstall.sh" "${stage}/uninstall.sh"
sed "s/@VERSION@/${version}/g" "${script_dir}/PACKAGE_README.md" \
  > "${stage}/README.md"

echo "==> Creating tarball ..."
tar -C "${out_dir}" -czf "${out_dir}/${pkg_name}.tar.gz" "${pkg_name}"

echo
echo "Done: ${out_dir}/${pkg_name}.tar.gz"
echo "Install on a target machine with:"
echo "  tar xzf ${pkg_name}.tar.gz && cd ${pkg_name} && sudo ./install.sh"
