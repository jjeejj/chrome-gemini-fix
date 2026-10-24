#!/bin/bash
#
# install.sh —— 安装 glic 命令 + 「Chrome (Gemini)」启动图标
#
# 三种用法：
#
#   1) 本地（git clone 之后）
#        ./install.sh
#
#   2) 远程直接执行（无需 clone，仓库私有，走 gh 的登录态）
#        gh api repos/jjeejj/chrome-gemini-fix/contents/install.sh \
#          --jq .content | base64 -D | bash
#
#   3) 卸载
#        ./install.sh --uninstall
#        # 或远程：
#        gh api repos/jjeejj/chrome-gemini-fix/contents/install.sh \
#          --jq .content | base64 -D | bash -s -- --uninstall
#
# 可用环境变量覆盖：
#   GLIC_REPO  默认 jjeejj/chrome-gemini-fix
#   GLIC_REF   默认 main
#
# 安装后先别急着打开 Chrome，跑一次  glic apply  完成字段修复和加锁。

set -euo pipefail

REPO="${GLIC_REPO:-jjeejj/chrome-gemini-fix}"
REF="${GLIC_REF:-main}"

GLIC_DST="$HOME/.local/bin/glic"
APP="$HOME/Applications/Chrome (Gemini).app"
CHROME="/Applications/Google Chrome.app"
CHROME_BIN="$CHROME/Contents/MacOS/Google Chrome"

info() { printf '\033[36m→\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }
die()  { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

# 定位脚本所在目录；管道执行时 BASH_SOURCE 为空
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# ---------- 卸载（不需要 glic，先处理） ----------
if [ "${1:-}" = "--uninstall" ]; then
  info "解除 Local State 锁定（如果已锁）"
  LS="$HOME/Library/Application Support/Google/Chrome/Local State"
  if [ -f "$LS" ]; then
    if pgrep -f "MacOS/Google Chrome" >/dev/null 2>&1; then
      warn "Chrome 正在运行，先退出，否则锁定可能被写回"
      osascript -e 'tell application "Google Chrome" to quit' 2>/dev/null || true
      sleep 3
      pkill -f "MacOS/Google Chrome" 2>/dev/null || true
      sleep 1
    fi
    if chflags nouchg "$LS" 2>/dev/null; then
      ok "已解锁 Local State"
    else
      warn "解锁失败或本来就未锁"
    fi
  fi
  rm -rf "$APP" && ok "已删除启动图标"
  rm -f "$GLIC_DST" && ok "已删除 glic 命令"
  info "卸载完成。Chrome 恢复写配置（Gemini 侧边栏随之失效）"
  exit 0
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'EOM'
install.sh —— 安装 glic 命令 + 「Chrome (Gemini)」启动图标

用法：
  ./install.sh                 本地安装（需同目录有 glic）
  ./install.sh --uninstall     卸载（解锁 + 删除图标和命令）

远程执行（无需 clone）：
  gh api repos/jjeejj/chrome-gemini-fix/contents/install.sh \
    --jq .content | base64 -D | bash

环境变量：
  GLIC_REPO   默认 jjeejj/chrome-gemini-fix
  GLIC_REF    默认 main

安装后需执行一次 glic apply 完成修复和加锁。
EOM
  exit 0
fi

# ---------- 前置检查 ----------
[ "$(uname -s)" = "Darwin" ] || die "只支持 macOS"
[ -x "$CHROME_BIN" ] || die "找不到 Google Chrome，请确认装在 /Applications"
command -v python3 >/dev/null 2>&1 || die "需要 python3"

# ---------- 取得 glic ----------
GLIC_SRC="$SCRIPT_DIR/glic"
TMPD=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT

if [ ! -f "$GLIC_SRC" ]; then
  info "本地没有 glic，进入远程模式从 $REPO@$REF 拉取"
  TMPD="$(mktemp -d)"
  GLIC_SRC="$TMPD/glic"

  fetch_ok=0
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if gh api "repos/$REPO/contents/glic?ref=$REF" --jq .content 2>/dev/null \
         | base64 -D > "$GLIC_SRC" 2>/dev/null && [ -s "$GLIC_SRC" ]; then
      fetch_ok=1
      ok "已通过 gh 拉取 glic（私有仓库）"
    fi
  fi

  if [ "$fetch_ok" -eq 0 ]; then
    if curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/glic" -o "$GLIC_SRC" 2>/dev/null \
         && [ -s "$GLIC_SRC" ]; then
      fetch_ok=1
      ok "已通过 curl 拉取 glic（公开仓库）"
    fi
  fi

  if [ "$fetch_ok" -eq 0 ]; then
    die "拉取 glic 失败。仓库是私有的，需要先登录 gh：gh auth login
   或者改为公开仓库后即可用 curl 方式。
   也可以直接 git clone 后本地执行 ./install.sh"
  fi

  # 简单校验，避免把半截内容装进去
  head -1 "$GLIC_SRC" | grep -q '^#!.*python3' || die "拉取到的 glic 内容不合法（首行不是 python shebang）"
  python3 -m py_compile "$GLIC_SRC" 2>/dev/null || die "拉取到的 glic 语法检查失败"
  ok "glic 内容校验通过"
fi

# ---------- 安装 glic ----------
mkdir -p "$HOME/.local/bin"
install -m 755 "$GLIC_SRC" "$GLIC_DST"
ok "已安装 $GLIC_DST"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ok "$HOME/.local/bin 已在 PATH 中" ;;
  *) warn "$HOME/.local/bin 不在 PATH，请加入后重开终端：" \
          'export PATH="$HOME/.local/bin:$PATH"' ;;
esac

# ---------- 生成启动图标 ----------
info "生成启动图标 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/MacOS/ChromeGemini" <<'EOS'
#!/bin/sh
# 以美国国家码模式启动 Chrome
# 参数只在启动瞬间有效，所以 Chrome 已在运行时直接拒绝
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if pgrep -f "MacOS/Google Chrome" >/dev/null 2>&1; then
  osascript -e 'display dialog "Chrome 已经在运行，启动开关传不进去。" & return & return & "请先在 Chrome 里按 Cmd+Q 完全退出，再点这个图标。" buttons {"好"} default button 1 with title "Chrome (Gemini)" with icon caution'
  exit 0
fi

exec "$CHROME" --variations-override-country=us
EOS
chmod +x "$APP/Contents/MacOS/ChromeGemini"

cat > "$APP/Contents/Info.plist" <<'EOP'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Chrome (Gemini)</string>
  <key>CFBundleDisplayName</key><string>Chrome (Gemini)</string>
  <key>CFBundleIdentifier</key><string>local.glic.chrome-gemini</string>
  <key>CFBundleExecutable</key><string>ChromeGemini</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOP

# 图标直接复用本机 Chrome 的资源，不把 Google 的美术资源塞进仓库
[ -f "$CHROME/Contents/Resources/Assets.car" ] && \
  cp "$CHROME/Contents/Resources/Assets.car" "$APP/Contents/Resources/Assets.car"
[ -f "$CHROME/Contents/Resources/app.icns" ] && \
  cp "$CHROME/Contents/Resources/app.icns" "$APP/Contents/Resources/AppIcon.icns"

plutil -lint "$APP/Contents/Info.plist" >/dev/null || die "Info.plist 校验失败"
touch "$APP"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREG" ] && "$LSREG" -f "$APP" >/dev/null 2>&1 || true
ok "已生成启动图标"

echo
info "安装完成。接下来："
echo "   1. 完全退出 Chrome（Cmd+Q）"
echo "   2. 执行：glic apply"
echo "   3. 之后只用「Chrome (Gemini)」图标或 glic launch 启动 Chrome"
echo
warn "注意：锁定生效期间 chrome://flags 的改动不会被保存，"
warn "      要改 flags 请按  glic unlock → 改 → glic apply  的顺序操作。"
