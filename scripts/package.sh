#!/bin/bash
# 构建 MijiaBar.app 并打包 DMG。
#   有 Developer ID 证书时：hardened runtime 签名 → 公证 → staple
#   没有证书时：ad-hoc 签名，DMG 文件名带 -unsigned
# 环境变量：
#   VERSION         版本号（默认读取 docs/VERSION）
#   ARCHS           默认 "--arch arm64 --arch x86_64"
#   SIGN_IDENTITY   签名身份；默认自动找 "Developer ID Application"，设为 "-" 强制 ad-hoc
#   KEYCHAIN        可选签名钥匙串，用于查找身份和 codesign
#   NOTARY_PROFILE  默认 MijiaBar-notary；显式设为空且无 ASC 配置时跳过公证
#   ASC_API_KEY_PATH / ASC_API_KEY_ID / ASC_API_ISSUER_ID  全部设置时优先用 API 密钥公证
#   REQUIRE_NOTARIZATION  设为 1 时，真实签名必须有公证配置（ad-hoc 不受影响）
#   SKIP_APPCAST    设为 1 时跳过 appcast 生成
#   HOUSE_STYLE_BUNDLE  all（默认）或 default
set -euo pipefail
cd "$(dirname "$0")/.."
HOUSE_STYLE_BUNDLE="${HOUSE_STYLE_BUNDLE:-all}"
case "$HOUSE_STYLE_BUNDLE" in all|default) ;; *) echo "Invalid HOUSE_STYLE_BUNDLE: $HOUSE_STYLE_BUNDLE" >&2; exit 1 ;; esac
export HOUSE_STYLE_BUNDLE
VERSION="${VERSION:-$(cat docs/VERSION)}"
ARCHS="${ARCHS:---arch arm64 --arch x86_64}"
NOTARY_PROFILE="${NOTARY_PROFILE-MijiaBar-notary}"
ENT=Resources/MijiaBar.entitlements
APP=dist/MijiaBar.app
KEYCHAIN_ARGS=()
[ -z "${KEYCHAIN:-}" ] || KEYCHAIN_ARGS=(--keychain "$KEYCHAIN")
NOTARY_ARGS=()
if [ -n "${ASC_API_KEY_PATH:-}" ] && [ -n "${ASC_API_KEY_ID:-}" ] && [ -n "${ASC_API_ISSUER_ID:-}" ]; then
  NOTARY_ARGS=(--key "$ASC_API_KEY_PATH" --key-id "$ASC_API_KEY_ID" --issuer "$ASC_API_ISSUER_ID")
elif [ -n "$NOTARY_PROFILE" ]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
fi

if [ -z "${SIGN_IDENTITY:-}" ]; then
  IDENTITY_ARGS=()
  [ -z "${KEYCHAIN:-}" ] || IDENTITY_ARGS=("$KEYCHAIN")
  SIGN_IDENTITY=$(security find-identity -v -p codesigning ${IDENTITY_ARGS[@]+"${IDENTITY_ARGS[@]}"} 2>/dev/null | grep -o '"Developer ID Application:[^"]*"' | head -1 | tr -d '"' || true)
  [ -z "$SIGN_IDENTITY" ] && SIGN_IDENTITY="-"
fi
if [ "$SIGN_IDENTITY" = "-" ]; then
  DMG="dist/MijiaBar-$VERSION-unsigned.dmg"; echo "⚠️  未找到 Developer ID，使用 ad-hoc 签名"
else
  DMG="dist/MijiaBar-$VERSION.dmg"; echo "🔏 签名身份: $SIGN_IDENTITY"
  if [ "${REQUIRE_NOTARIZATION:-0}" = "1" ] && [ "${#NOTARY_ARGS[@]}" = "0" ]; then
    echo "❌ REQUIRE_NOTARIZATION=1，但未配置 NOTARY_PROFILE 或完整的 ASC API 密钥" >&2; exit 1
  fi
fi

# 内置 go2rtc（MIT，github.com/AlexxIT/go2rtc）：构建时下载官方发布包并校验 SHA-256，二进制不进仓库
GO2RTC_VERSION=v1.9.14
GO2RTC_SHA_arm64=919b78adc759d6b3883d1e1b2ac915ac0985bb903ff1897b4d228527bd64690c
GO2RTC_SHA_amd64=9b0b9a27a4dc3a5b8b93376e7e8fc2787c6af624a512842622be84aec0171c7a
G2=.build/go2rtc/$GO2RTC_VERSION && mkdir -p "$G2"
for a in arm64 amd64; do
  z="$G2/go2rtc_mac_$a.zip"; want=$(eval echo \$GO2RTC_SHA_$a)
  [ -f "$z" ] || curl -fsSL -o "$z" "https://github.com/AlexxIT/go2rtc/releases/download/$GO2RTC_VERSION/go2rtc_mac_$a.zip"
  got=$(shasum -a 256 "$z" | cut -d' ' -f1)
  [ "$got" = "$want" ] || { echo "❌ go2rtc_mac_$a.zip 校验失败: $got"; rm -f "$z"; exit 1; }
  rm -rf "$G2/$a" && mkdir -p "$G2/$a" && unzip -q -o "$z" -d "$G2/$a"
done
[ -f "$G2/LICENSE" ] || curl -fsSL -o "$G2/LICENSE" "https://raw.githubusercontent.com/AlexxIT/go2rtc/$GO2RTC_VERSION/LICENSE"
lipo -create "$G2/arm64/go2rtc" "$G2/amd64/go2rtc" -output "$G2/go2rtc" && chmod 755 "$G2/go2rtc"

# Sparkle 2.10（XCFramework + 签名工具，校验 SHA，不进仓库）
scripts/fetch-sparkle.sh

swift build -c release $ARCHS
BIN="$(swift build -c release $ARCHS --show-bin-path)"
[ -d "$BIN/MijiaBar_MijiaBarApp.bundle" ] || { echo "❌ Missing SwiftPM resource bundle: $BIN/MijiaBar_MijiaBarApp.bundle" >&2; exit 1; }

FW=".build/sparkle/spm/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[ -d "$FW" ] || { echo "❌ 找不到 $FW"; exit 1; }
echo "📦 Sparkle.framework ← $FW"

rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin" "$APP/Contents/Frameworks"
for bundle in "$BIN"/*.bundle; do
  [ -d "$bundle" ] || continue
  cp -a "$bundle" "$APP/Contents/Resources/"
done
if [ "$HOUSE_STYLE_BUNDLE" = all ]; then
for style in japanese modern light-wood walnut; do
  mkdir -p "$APP/Contents/Resources/House/styles/$style"
  cp "assets/house/styles/$style/manifest.json" "$APP/Contents/Resources/House/styles/$style/"
  for sub in modules classic; do
    source="assets/house/styles/$style/$sub"
    [ -d "$source" ] || continue
    destination="$APP/Contents/Resources/House/styles/$style/$sub"
    mkdir -p "$destination"
    if [ -f "$source/catalog.json" ]; then
      cp "$source/catalog.json" "$destination/"
    fi
    for png in "$source"/*.png; do
      [ -f "$png" ] || continue
      cp "$png" "$destination/"
    done
  done
done
fi
scripts/verify-app-bundle.sh "$APP"
cp "$BIN/MijiaBarApp" "$APP/Contents/MacOS/MijiaBar"
cp "$BIN/mijiabar" "$APP/Contents/Resources/bin/mijiabar"
cp "$G2/go2rtc" "$APP/Contents/Resources/bin/go2rtc"
cp "$G2/LICENSE" "$APP/Contents/Resources/go2rtc-LICENSE.txt"
# 保留框架符号链接
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -a "$FW" "$APP/Contents/Frameworks/Sparkle.framework"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

# 可执行文件需要能找到 @rpath/Sparkle.framework
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/MijiaBar" 2>/dev/null || true

sign() {
  if [ "$SIGN_IDENTITY" = "-" ]; then codesign --force --sign - --timestamp=none ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} "$@"
  else codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} "$@"; fi
}
# 由内向外签名：先 helpers / framework，再 app
sign --identifier com.neardws.MijiaBar.cli --entitlements "$ENT" "$APP/Contents/Resources/bin/mijiabar"
sign --identifier com.neardws.MijiaBar.go2rtc --entitlements "$ENT" "$APP/Contents/Resources/bin/go2rtc"
# Sparkle 内部 XPC / Autoupdate 也要签
if [ -d "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" ]; then
  find "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" -name '*.xpc' -maxdepth 1 | while read -r xpc; do
    sign --identifier "com.neardws.MijiaBar.$(basename "$xpc" .xpc)" "$xpc" || sign "$xpc"
  done
fi
if [ -d "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" ]; then
  sign --identifier com.neardws.MijiaBar.Updater "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" || true
fi
if [ -f "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" ]; then
  sign --identifier com.neardws.MijiaBar.Autoupdate "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" || true
fi
sign --identifier org.sparkle-project.Sparkle "$APP/Contents/Frameworks/Sparkle.framework"
sign --entitlements "$ENT" "$APP"
codesign --verify --strict --verbose=2 "$APP"
scripts/verify-app-bundle.sh "$APP"

STAGE=dist/dmg && mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "MijiaBar" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [ "$SIGN_IDENTITY" != "-" ]; then
  codesign --force --sign "$SIGN_IDENTITY" --timestamp ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} "$DMG"
  if [ "${#NOTARY_ARGS[@]}" != "0" ]; then
    echo "📮 提交公证…"
    xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait | tee dist/notary.log
    grep -q "status: Accepted" dist/notary.log || { echo "❌ 公证失败，用相同凭据执行 xcrun notarytool log <id> 查看"; exit 1; }
    xcrun stapler staple "$APP"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl -a -vv "$APP"
    spctl -a -vvv -t install "$DMG"
  fi
fi
echo "✅ $DMG"

# 公证成功后生成 / 更新 GitHub Pages 用的 appcast（私钥不在仓库）
if [ "${SKIP_APPCAST:-0}" != "1" ] && [ "$SIGN_IDENTITY" != "-" ] && [ -f "$DMG" ]; then
  VERSION="$VERSION" DMG_PATH="$DMG" scripts/generate-appcast.sh || echo "⚠️  appcast 未生成（可稍后手动跑 scripts/generate-appcast.sh）"
fi
