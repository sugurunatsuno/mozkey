# Mozkey @VERSION@ for Linux (fcitx5)

Mozkey（もずきー）の Linux / fcitx5 向けバイナリパッケージです。
[google/mozc](https://github.com/google/mozc) をベースにした非公式 fork であり、
Google 日本語入力および公式 Mozc とは無関係です。

## 同梱物

| ファイル | インストール先 |
| --- | --- |
| `lib/mozkey/mozc_server` ほか | `/usr/lib/mozkey/` |
| `lib/fcitx5/fcitx5-mozc.so` | fcitx5 の addon ディレクトリ（自動検出） |
| `share/fcitx5/...` | `/usr/share/fcitx5/`（addon / inputmethod 定義） |
| `share/icons/...` | `/usr/share/icons/hicolor/` |
| `share/locale/...` | `/usr/share/locale/`（fcitx5 addon の翻訳） |

## インストール

```sh
sudo ./install.sh
```

- ディストリの `fcitx5-mozc` / `mozc-server` 等が入っている場合は、先に
  アンインストールするよう促されます（`--force` で強行も可能ですが、
  パッケージ更新時に上書きされて Mozkey が消えるので非推奨です）。
- インストール後、fcitx5 を再起動し、fcitx5-configtool で入力メソッドに
  「Mozc」を追加してください。

## アンインストール

```sh
sudo ./uninstall.sh
```

ユーザー辞書・設定（`~/.config/mozkey`）は削除されません。

## 動作要件

- fcitx5（ビルド環境と同等以上のバージョン）
- Qt6 ランタイム（`mozc_tool` / `mozc_renderer` が使用。Debian/Ubuntu では
  `libqt6widgets6` など）
- このパッケージはビルド元マシンと同系統・同世代以降の glibc を持つ
  ディストリビューションで動作します。動かない場合はソースからビルド
  してください（リポジトリの `docs/build_fcitx5_for_linux.md` を参照）。

## ライセンス

Mozc 由来のコードは BSD-3-Clause、fcitx5 連携部分（`unix/fcitx5`）は
GPL-2.0+ です。外部辞書等の出典はリポジトリの `THIRD_PARTY_NOTICES.md` を
参照してください。
