# イシューツリー

キーボードだけでイシューツリー・ロジックツリーを素早く作れる macOS アプリ（SwiftUI）。
サブイシューを「深掘り」して、新しいツリーとして分け直せます。

- 紹介ページ・ダウンロード: https://jinshin2534.github.io/rogic-issue-tree/

## ビルド

```sh
swift test                      # コアのテスト
./scripts/build-app.sh          # build/イシューツリー.app を生成
./scripts/build-app.sh --zip    # 配布用 zip も生成
swift scripts/make-icon.swift   # アイコンを作り直す
```

macOS 14 以降、Xcode 16 以降が必要です。
