# veronork

## 概要

Rcloneでタイムスタンプが実行時の先月になっているファイル、もしくはファイル名がyyyyMMdd.zipとなっているファイルを転送するツールです。

## 開発環境

- Windows10 Enterprise 1909
- PowerShell 5.1
- Rclone 1.50.2

## 使い方

- [Rclone](https://rclone.org/) をダウンロードしてPATHを通す
  - https://github.com/rclone/rclone/releases
  - windows用実行ファイルをダウンロード、 _C:\rclone_ 等に展開してシステム環境変数 _PATH_ に追記
  - もしくは[chocolatey](https://chocolatey.org/)でインストール
- このリポジトリをgit clone(あるいはこのリポジトリのzipファイルを展開)
- main.ps1と同じフォルダに下記2つの設定ファイルを配置
  - config.ps1
  - rclone.conf
- PowerShellでmain.ps1を実行

## 設定ファイル

### config.ps1

例
```
$findscheme = "timestamp"
$source_path_prefix = "sftp:/dairy-logs/"
$distination_path_prefix = "cloud-storage:/archive/dairy-logs/"
$distination_format = "yyyy/MM/"
$time_format = "yyyy-MM-dd hh:mm:ss"
$webhook_uri = "https://example.com/webhook/foobar"
```

_$webhook_uri_ が未設定の場合通知は行われません。

### rclone.conf

`rclone config`コマンドで作成。
