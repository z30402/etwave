#!/usr/bin/env bash
# etwave 反編譯重現腳本
# 從 Wave 的 XAPK 解出 APK，用 apktool 解 Manifest/資源、jadx 反編譯 Java，
# 並匯出直播/禮物相關的關鍵原始碼。即使刪掉舊的 Wave_5.98.0_analysis 也能重跑。
#
# 需求：bash、java (JDK 17+)、unzip、curl、python3
# 用法：  tools/decompile.sh /path/to/Wave_x.xx.x_APKPure.xapk  [輸出資料夾]
# 範例：  tools/decompile.sh ~/Downloads/Wave_5.98.0_APKPure.xapk ./wave_analysis
set -euo pipefail

XAPK="${1:?請提供 XAPK 路徑}"
OUT="${2:-./wave_analysis}"
PKG="com.wave.waveradio"
JADX_VER="1.5.1"
APKTOOL_VER="2.10.0"

command -v java >/dev/null  || { echo "缺 java (JDK 17+)"; exit 1; }
command -v unzip >/dev/null || { echo "缺 unzip"; exit 1; }
command -v curl >/dev/null  || { echo "缺 curl"; exit 1; }

WORK="$(mkdir -p "$OUT" && cd "$OUT" && pwd)"
TOOLS="$WORK/.tools"
mkdir -p "$TOOLS" "$WORK/xapk" "$WORK/apk" "$WORK/manifest" "$WORK/src"

echo "==> 1/5 解開 XAPK"
unzip -o -q "$XAPK" -d "$WORK/xapk"
BASE_APK="$WORK/xapk/${PKG}.apk"
[ -f "$BASE_APK" ] || BASE_APK="$(find "$WORK/xapk" -maxdepth 1 -name '*.apk' ! -name 'config.*' | head -1)"
cp "$BASE_APK" "$WORK/apk/${PKG}.apk"
echo "    base APK: $BASE_APK"

echo "==> 2/5 下載工具 (jadx $JADX_VER / apktool $APKTOOL_VER)"
if [ ! -x "$TOOLS/jadx/bin/jadx" ]; then
  curl -sSL -o "$TOOLS/jadx.zip" \
    "https://github.com/skylot/jadx/releases/download/v${JADX_VER}/jadx-${JADX_VER}.zip"
  mkdir -p "$TOOLS/jadx" && unzip -o -q "$TOOLS/jadx.zip" -d "$TOOLS/jadx"
fi
if [ ! -f "$TOOLS/apktool.jar" ]; then
  curl -sSL -o "$TOOLS/apktool.jar" \
    "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VER}/apktool_${APKTOOL_VER}.jar"
fi

echo "==> 3/5 apktool 解碼 Manifest / 資源"
java -jar "$TOOLS/apktool.jar" d -f -s -o "$WORK/base_res" "$WORK/apk/${PKG}.apk" >/dev/null
cp "$WORK/base_res/AndroidManifest.xml" "$WORK/manifest/AndroidManifest.xml"

echo "==> 4/5 jadx 反編譯 Java（--no-res，數分鐘）"
"$TOOLS/jadx/bin/jadx" -j 4 --no-res -d "$WORK/jadx" "$WORK/apk/${PKG}.apk" >/dev/null 2>&1 || true
SRC="$WORK/jadx/sources"

echo "==> 5/5 匯出直播 / 禮物關鍵原始碼"
copy() { local p="$SRC/$1"; [ -e "$p" ] && { mkdir -p "$WORK/src/$(dirname "$1")"; cp -r "$p" "$WORK/src/$1"; }; }
# 直播（觀眾/主播）
copy com/wave/waveradio/live
copy com/wave/waveradio/service/PushStreamingService.java
# 禮物資料流 / 設定 / DTO / API
copy com/wave/waveradio/dto/gift
copy com/wave/waveradio/dto/config
copy com/wave/waveradio/dto/LiveDto.java
copy com/wave/waveradio/api/gift
copy com/wave/waveradio/api/message
# 聊天即時推播（PubNub / Ably）
copy com/wave/waveradio/dto/message/pubsub
for pkg in y5 R7 H5 I5 M5 d6 E5 C5 D5 k4 m4 o4 p4 r4; do copy "$pkg"; done

echo
echo "完成。輸出在：$WORK"
echo "  manifest/AndroidManifest.xml  權限與 Activity"
echo "  src/...                       直播 / 禮物 / 聊天 關鍵原始碼"
echo "  jadx/sources/                 完整反編譯（可自行搜尋）"
echo "逆向重點與 API 結構見 docs/REVERSE_ENGINEERING.md"
