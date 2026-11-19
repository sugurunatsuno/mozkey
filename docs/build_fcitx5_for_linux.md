# Mozkey を Linux (fcitx5) 向けにビルド・配布する

Mozkey の Linux 対応は [fcitx5](https://github.com/fcitx/fcitx5) 用の
入力メソッドアドオンとして提供します。fcitx5 連携部分
（[`src/unix/fcitx5/`](../src/unix/fcitx5/)）は
[fcitx/mozc](https://github.com/fcitx/mozc) 由来のコード（GPL-2.0+）です。

> [!NOTE]
> この Linux/fcitx5 対応は、upstream が公式に Linux をサポートするまでの
> 暫定実装です。fcitx5 連携部分は
> [soichi11208/fcitx5-mozkey](https://github.com/soichi11208/fcitx5-mozkey)
> から取り込んでいます。Mozkey 本体はこのリポジトリの `main` に追従します。

upstream Mozc の Linux ビルド全般については
[build_mozc_for_linux.md](build_mozc_for_linux.md) も参照してください。

## 手っ取り早い手順

```sh
# ビルド依存を入れて（下記「ビルド要件」参照）:
scripts/fcitx5-linux/build_package.sh
```

成功すると `dist/linux/mozkey-fcitx5-<version>-<arch>.tar.gz` ができます。
これが配布物です。導入したいマシンに持っていき:

```sh
tar xzf mozkey-fcitx5-<version>-<arch>.tar.gz
cd mozkey-fcitx5-<version>-<arch>
sudo ./install.sh
```

でインストールできます（`sudo ./uninstall.sh` で削除）。
インストール後は fcitx5 を再起動し、`fcitx5-configtool` で入力メソッドに
「Mozc」を追加してください。

> [!NOTE]
> ディストリの `fcitx5-mozc` / `mozc-server` パッケージが入っている場合、
> `install.sh` は上書きを拒否します。先に `sudo apt remove fcitx5-mozc
> mozc-server mozc-utils-gui` などで削除してください
> （ユーザー辞書 `~/.config/mozkey` は消えません）。

## ビルド要件

- Bazel（[`src/.bazeliskrc`](../src/.bazeliskrc) 指定のバージョン。
  bazelisk の使用を推奨）
- C++ ツールチェーン（GCC または Clang）
- fcitx5 開発パッケージ（pkg-config で `Fcitx5Core` / `Fcitx5Module` が
  引けること)
- Qt6 開発パッケージ（`mozc_tool` / `mozc_renderer` 用）
- gettext（fcitx5 アドオンの翻訳 `.mo` 生成用。無くてもビルドは可能）

Debian / Ubuntu の場合:

```sh
sudo apt install build-essential pkgconf gettext bazelisk \
  libfcitx5core-dev libfcitx5config-dev libfcitx5utils-dev \
  fcitx5-modules-dev qt6-base-dev
```

Arch Linux の場合:

```sh
sudo pacman -S --needed base-devel bazelisk fcitx5 qt6-base gettext
```

## 何がビルド・パッケージされるか

`scripts/fcitx5-linux/build_package.sh` は
`bazel build --config release_build` で以下をビルドし、
インストールスクリプト込みの tar.gz にまとめます。

| Bazel ターゲット | tarball 内 | インストール先 |
| --- | --- | --- |
| `//server:mozc_server` | `lib/mozkey/mozc_server` | `/usr/lib/mozkey/` |
| `//gui/tool:mozc_tool` | `lib/mozkey/mozc_tool` | `/usr/lib/mozkey/` |
| `//renderer/qt:mozc_renderer` | `lib/mozkey/mozc_renderer` | `/usr/lib/mozkey/` |
| `//unix/fcitx5:fcitx5-mozc.so` | `lib/fcitx5/fcitx5-mozc.so` | fcitx5 addon dir（自動検出） |
| `//unix:icons` | `share/icons/hicolor/...` | `/usr/share/icons/hicolor/` |
| （conf ファイル） | `share/fcitx5/...` | `/usr/share/fcitx5/` |
| （`po/*.po` → `.mo`） | `share/locale/...` | `/usr/share/locale/` |

fcitx5 の addon ディレクトリは `install.sh` が
`pkg-config --variable=libdir Fcitx5Core` →
`/usr/lib/<multiarch>/fcitx5` → `/usr/lib64/fcitx5` → `/usr/lib/fcitx5`
の順で自動検出します。特殊な環境では
`MOZKEY_FCITX5_ADDON_DIR=/path/to/fcitx5 sudo -E ./install.sh` で
明示できます。

## バイナリ配布の互換性について

tar.gz 内のバイナリは、ビルドしたマシンの glibc / Qt6 / fcitx5 に動的
リンクされています。おおむね「ビルド元と同世代以降の glibc を持ち、
fcitx5 と Qt6 ランタイムが入っているディストリ」で動きます。
古いディストリや異なる libc（musl 等）では動かないので、その場合は
ターゲット環境上で本手順どおりソースからビルドしてください。

## 開発時のワンライナー

パッケージを作らず、ビルドした `.so` だけ試したい場合:

```sh
cd src
bazel build //unix/fcitx5:fcitx5-mozc.so
sudo install -m 644 bazel-bin/unix/fcitx5/fcitx5-mozc.so \
  "$(pkg-config --variable=libdir Fcitx5Core)/fcitx5/fcitx5-mozc.so"
fcitx5 -rd >/dev/null 2>&1 &
```

サーバー側（変換エンジン）を試す場合は `//server:mozc_server` を
`/usr/lib/mozkey/mozc_server` に置き、既存の `mozc_server` プロセスを
`pkill -f mozc_server` で終了させてから再変換してください。
