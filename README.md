# AIokan

## セットアップ手順

このプロジェクトを実行するには、以下の手順に従ってください：

### 1. リポジトリのクローン
```bash
git clone <リポジトリURL>
cd AIokan
```

### 2. Secrets.plistの作成
このファイルには機密情報が含まれるため、Gitで共有されていません。以下の手順で作成してください：

1. Xcodeでプロジェクトを開く
2. 「AIokan」フォルダを右クリックし、「New File...」を選択
3. 「Property List」を選択し、ファイル名を「Secrets.plist」に設定
4. 以下の内容をコピーして貼り付ける：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GIDClientID</key>
    <string>あなたのGoogleクライアントID</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.googleusercontent.apps.あなたのGoogleクライアントID</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

※適切なクライアントIDを入力してください（開発者から提供されます）

### 3. 依存関係のインストール（必要に応じて）
```bash
pod install
```

### 4. プロジェクトのビルドと実行
Xcodeでプロジェクトを開き、ビルドして実行します。

## 注意事項
- Secrets.plistファイルをGitにコミットしないでください。
- 問題が発生した場合は、開発者に連絡してください。 
