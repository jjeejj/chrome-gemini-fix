# chrome-gemini-fix

在**非美国地区**启用 Chrome 内置的 Gemini 侧边栏（内部代号 **Glic**）的本地方案。

> 现象：侧边栏显示「Gemini in Chrome isn't available — Gemini in Chrome is expanding to different locations but isn't available everywhere」，带定位图标。
> 适用：macOS + Google Chrome 正式版（实测 156.0.8078.48）。

---

## 原理一句话

Chrome 的地域门禁读的是**本地两个字段**，而 Chrome 每次启动都会从 Google 的 variations seed 把它们改回中国状态。所以：

1. 用 `chflags uchg` 把 `Local State` 锁成不可写 → Chrome 改不回去
2. 启动时加 `--variations-override-country=us` → 强制国家码为 `us`

**两个条件缺一不可。**

| 组合 | 结果 |
|---|---|
| 只锁文件、不带开关 | `previously_not_allowed` 20 秒内翻回 `true`，立刻失效 |
| 只带开关、不锁文件 | `variations_country` 被覆写回 `cn`，几分钟内失效 |
| 锁文件 + 带开关 | 稳定可用 |

---

## 快速开始

```bash
git clone <this-repo> chrome-gemini-fix
cd chrome-gemini-fix
./install.sh
```

安装脚本会：

- 把 `glic` 装到 `~/.local/bin/`
- 生成 `~/Applications/Chrome (Gemini).app`（图标复用本机 Chrome 的资源）

然后：

```bash
# 1. 完全退出 Chrome（Cmd+Q）
# 2. 一键修复 + 加锁 + 启动
glic apply
```

此后**只用「Chrome (Gemini)」图标或 `glic launch` 启动 Chrome**，直接点原版 Chrome 会失效。

---

## 命令

| 命令 | 作用 |
|---|---|
| `glic` / `glic status` | 查看状态 |
| `glic apply`（= `glic on`） | 退出 Chrome → 修复字段 → 加锁 → 带开关启动 |
| `glic unlock`（= `glic off`） | 解除锁定 |
| `glic launch` | 带开关启动（Chrome 必须先是关着的） |
| `glic -h` | 帮助 |

自查就是跑 `glic`，两行都正常才是好的：

```
override 开关      : 已生效
previously_not_allowed: False
```

> 只看 `variations_country = us` 会被骗——文件里是 `us`，Chrome 内存里可能已经是 `cn`。

---

## 代价（重要）

锁定期间 Chrome 无法写 `Local State`：

- ⚠️ `chrome://flags` 里改任何开关**都不会保存**
- ⚠️ 全局 UI 状态（上次用的 profile 等）不持久化
- ✅ 书签 / 历史 / 密码 / Cookie / 扩展**完全不受影响**（在 profile 目录里）

要改 flags 时按这个顺序：

```bash
glic unlock                 # 解锁 + 退出 Chrome
# 打开 Chrome（此时用原版图标即可），改 flags，Cmd+Q
glic apply                  # 重新修复 + 加锁 + 带开关启动
```

---

## 卸载

```bash
./install.sh --uninstall
```

会解除锁定、删除启动图标和 `glic` 命令。Chrome 恢复正常写配置（Gemini 侧边栏随之失效）。

---

## 文档

完整的技术细节、根因分析、实测数据和踩坑记录见 **[docs/修复方案.md](docs/修复方案.md)**。

---

## 风险提示

这是一个**非官方的本地绕过手段**，不是修复。它通过让 Chrome 写不了全局配置文件来实现目的，因此带有上面的副作用。Chrome 大版本更新后可能需要重跑一次 `glic apply`。

如果 Google 后续把这个判定完全移到服务端，本方案会失效。
