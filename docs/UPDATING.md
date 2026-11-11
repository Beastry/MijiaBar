# 自动更新（Sparkle）与发布页

## 小屋风格包（手动维护，不属于发版脚本）

温馨木屋始终内置在 SwiftPM resource bundle。其余四包默认仍随 App 打包；R2 尚未上传时不要切换精简模式。
此流程不修改版本号、appcast 或 Sparkle，不需要把任何 R2 凭据写入仓库。

1. 素材变更时更新 `assets/house/styles/<id>/manifest.json` 的整数 `version`；已经上传的版本路径不可覆盖。
2. 执行 `scripts/build-style-packs.sh`（或指定输出目录）。输出 `dist/style-packs/<id>/<version>.zip` 和 `index.json`，
   同时生成 `Sources/MijiaBarApp/Resources/House/style-packs.json`。将该小型索引与素材修改一起提交，不提交 ZIP。
3. 执行 `scripts/build-style-packs.sh --check`：在临时目录重新构建，核对签入索引里的 SHA-256 和字节数。
   构建按路径排序、固定 2020-01-01 时间戳、固定 UNIX 文件权限、无 extra/comment 元数据（等效 `zip -X`）。
   使用 ZIP_STORED，PNG 本身已经压缩；避免 zlib/zip 版本差异改变哈希。同一输入字节产生完全相同的 ZIP。
4. 维护者在已认证的本机手动上传到绑定 `files.neardws.com` 的 R2 bucket，例如：

   ```bash
   scripts/build-style-packs.sh
   # BUCKET 是维护者的实际 bucket 名称；不要在脚本或仓库保存凭据。
   for id in japanese modern light-wood walnut; do
     version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "assets/house/styles/$id/manifest.json")
     wrangler r2 object put "$BUCKET/mijiabar/house/styles/$id/$version.zip" --remote \
       --file "dist/style-packs/$id/$version.zip" --content-type application/zip
   done
   wrangler r2 object put "$BUCKET/mijiabar/house/styles/index.json" --remote \
     --file dist/style-packs/index.json --content-type application/json
   ```

   也可以使用 R2 Dashboard 上传同样的 object keys。远端 index 方便维护者查看，客户端只信任随签名 App 内置的索引。
5. 维护者核对 HTTPS 公开 URL 可直接访问（不重定向），下载字节数和 SHA-256 与索引一致后，才使用
   `HOUSE_STYLE_BUNDLE=default scripts/package.sh`。默认 `HOUSE_STYLE_BUNDLE=all` 行为保持不变。
   `package.sh` 会清空 `dist/`，因此先上传或将包构建到独立目录，再进行 App 打包。
6. `scripts/verify-app-bundle.sh <App>` 总是检查默认素材与内置索引；指定 `HOUSE_STYLE_BUNDLE=all|default` 可验证
   对应模式，不指定时自动检测。可选风格仅出现一部分会失败。不要通过本步骤发布 App 或生成 appcast。

### 体积实测（当前四包 version 1）

`du -sk assets/house/styles/<id>/{modules,classic}`（不存在的 classic 忽略）与脚本 ZIP 输出：

| 风格 | modules + classic 磁盘占用（KiB） | ZIP 字节数 | 下载显示（MB，十进制） |
| --- | ---: | ---: | ---: |
| Japanese | 6,116 | 6,122,702 | 6.1 |
| Modern | 6,400 | 6,407,726 | 6.4 |
| Light wood | 9,524 | 9,563,089 | 9.6 |
| Walnut | 8,848 | 8,892,488 | 8.9 |
| 总计 | 30,888 | 30,986,005 | 31.0 |

精简模式移除约 30.2 MiB 的四包素材磁盘占用（不含极小的 manifest），而非声称 DMG 恰好缩小同样数值；
DMG 压缩、文件系统分配与签名都会影响最终大小。本次仅测量素材与 ZIP，未打包、公证或发布。

## Sparkle

应用内嵌 [Sparkle 2.10](https://sparkle-project.org/)（MIT）。`Info.plist`：

| 键 | 值 |
| --- | --- |
| `SUFeedURL` | `https://www.neardws.com/MijiaBar/appcast.xml` |
| `SUPublicEDKey` | `CCM7RPQimyjvvf3oCtszbmQ1hQArwEl1FwPQTVLolb4=`（公钥，可提交） |

**私钥**保存在维护者机器上，并可配置为仓库 Actions secret（不进入源码）：

```
~/mijiabar-private/sparkle/eddsa_priv.key
```

Keychain 账户名：`mijiabar`。切勿把私钥或 `~/mijiabar-private/` 提交进仓库。

### 发版流程

1. 首选 GitHub Actions → **Release** → **Run workflow**（`workflow_dispatch`），选择要发布的提交所在分支。`version` 不带 `v`；留空读取 `docs/VERSION`，也可在版本文件更新前显式填 `0.1.16`。`draft-release` 默认开启。
2. 工作流在 `macos-15` / Xcode 16 上签名、公证、staple 并验证 DMG；产物名带版本和 `adhoc` / `signed` / `notarized` 模式。只有公证成功且 `draft-release=true` 时才附加到 `v<version>` **草稿**。已有草稿只覆盖资产；已有正式发布则失败，不修改它。
3. 维护者下载产物核对 DMG、SHA-256、`notary.log` 和生成的 `appcast.xml`（需要 Sparkle secret），审核发布说明后，**手动发布草稿**。工作流从不发布、不推 tag；新草稿用所选提交作为目标，正式发布时由人确认 tag。关闭 `draft-release` 时仅保留 Actions 产物。
4. Release 正式可下载后，维护者将产物中的 `appcast.xml` 放回 `docs/appcast.xml`，把 `docs/VERSION` 更新为相同版本，再运行 `python3 scripts/gen-site.py`。将这三个部分（feed、VERSION、生成的 `docs/index.html` / `docs/zh-CN.html`）提交并推送到 `main`，Pages 才会提供新的更新 feed。**不要提前提交指向草稿资产的 appcast**；工作流不自动提交这些文件。
5. 已安装带 Sparkle 构建的用户可自动或手动检查到更新。enclosure 现使用 `https://github.com/Beastry/MijiaBar/releases/download/v<version>/…`；旧的 `neardws/MijiaBar` 下载链接仍重定向。网站与 feed 地址不变。

PR 仅在 Release workflow、打包 / appcast / 校验及 Sparkle 获取脚本变化时进行 ad-hoc dry run，**不使用 secrets**。原 `build.yml` 继续构建 unsigned DMG，并在 tag 上附加 `-unsigned` 资产；Release workflow 不监听 tag push，避免两条工作流竞争签名资产。

### Actions secrets

在 `Beastry/MijiaBar` → Settings → Secrets and variables → Actions 配置：

| Secret 名称 | 用途 |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Developer ID Application 证书与私钥的 P12，base64 编码 |
| `DEVELOPER_ID_P12_PASSWORD` | P12 导出密码 |
| `DEVELOPER_ID_IDENTITY` | 完整签名身份，末尾为 `(APPLE_TEAM_ID)` |
| `APPLE_TEAM_ID` | 校验签名身份的 Apple 团队 ID |
| `KEYCHAIN_PASSWORD` | 临时钥匙串密码；未设时工作流随机生成 |
| `ASC_API_KEY_ID` | App Store Connect API key ID |
| `ASC_API_ISSUER_ID` | API issuer ID |
| `ASC_API_KEY_P8_BASE64` | API P8 私钥，base64 编码 |
| `SPARKLE_ED_PRIVATE_KEY` | **MijiaBar 自己的** EdDSA 私钥文本，不是 Stow 的密钥；公钥必须匹配上面的 `SUPublicEDKey` |

以下均为占位符，实际值通过 stdin 交给 `gh`，不要写入源码或 shell 历史：

```bash
printf '%s' '<P12_BASE64>' | gh secret set DEVELOPER_ID_P12_BASE64 --repo Beastry/MijiaBar
printf '%s' '<P12_PASSWORD>' | gh secret set DEVELOPER_ID_P12_PASSWORD --repo Beastry/MijiaBar
printf '%s' '<DEVELOPER_ID_APPLICATION_IDENTITY>' | gh secret set DEVELOPER_ID_IDENTITY --repo Beastry/MijiaBar
printf '%s' '<APPLE_TEAM_ID>' | gh secret set APPLE_TEAM_ID --repo Beastry/MijiaBar
printf '%s' '<TEMP_KEYCHAIN_PASSWORD>' | gh secret set KEYCHAIN_PASSWORD --repo Beastry/MijiaBar
printf '%s' '<ASC_KEY_ID>' | gh secret set ASC_API_KEY_ID --repo Beastry/MijiaBar
printf '%s' '<ASC_ISSUER_ID>' | gh secret set ASC_API_ISSUER_ID --repo Beastry/MijiaBar
printf '%s' '<P8_BASE64>' | gh secret set ASC_API_KEY_P8_BASE64 --repo Beastry/MijiaBar
printf '%s' '<MIJIABAR_EDDSA_PRIVATE_KEY>' | gh secret set SPARKLE_ED_PRIVATE_KEY --repo Beastry/MijiaBar
```

不要把占位符替换成真实值后粘贴执行（会进入 shell 历史）；实际配置应使用密码管理器安全导出到 stdin，或运行不带输入重定向的 `gh secret set <NAME> --repo Beastry/MijiaBar` 交互输入。

缺少签名三项（P12、密码、身份）时降级为 ad-hoc；签名可用但 ASC 三项不全时只签名、不公证、不建草稿；签名时 `APPLE_TEAM_ID` 缺失或身份不匹配会失败。缺少 Sparkle secret 不阻止公证和草稿，但不生成 appcast，也不会自动更新用户。临时钥匙串、P12、P8 和 Sparkle 私钥文件在 `always()` 清理步骤删除。

### 本机备用路径（Mac mini A）

Mac mini A 仍是备用签名机：Developer ID 在 login keychain，Sparkle 私钥位于 `~/mijiabar-private/sparkle/eddsa_priv.key`，本地 notarytool profile 为 `MijiaBar-notary`。**不要把签名迁移到工作 Mac。** profile 丢失时，在 Mac mini A 上交互运行以下命令恢复（使用 Apple ID / App 专用密码，或 `store-credentials` 支持的 API key 参数；不要把密码写进命令行）：

```bash
xcrun notarytool store-credentials MijiaBar-notary
VERSION=x.y.z scripts/package.sh
```

本机路径会签名、公证并生成 `docs/appcast.xml`，随后人工上传 DMG 到 Release、正式发布，再按上述步骤更新 `docs/VERSION`、feed 和网站。`VERSION` 未设时读取 `docs/VERSION`；`SIGN_IDENTITY` 默认自动查找 Developer ID，`SIGN_IDENTITY=-` 强制 ad-hoc。

`KEYCHAIN` 可指定签名钥匙串。公证优先使用完整的 `ASC_API_KEY_PATH` / `ASC_API_KEY_ID` / `ASC_API_ISSUER_ID`，否则用默认 `NOTARY_PROFILE=MijiaBar-notary`；显式设 `NOTARY_PROFILE=` 且无完整 API 配置会跳过公证。`REQUIRE_NOTARIZATION=1` 在真实签名但无公证配置时提前失败（配置无效或公证失败也会退出），ad-hoc 不受影响。`SKIP_APPCAST=1` 可将 feed 生成留待后续步骤；`HOUSE_STYLE_BUNDLE` 行为不变。

### 从 0.1.8 迁移

0.1.8 及更早没有 Sparkle，**不会**自动升上来。需要手动安装一次带 Sparkle 的版本（本站或 Release DMG），之后才走自动更新。

### 仅重签 appcast

```bash
VERSION=x.y.z DMG_PATH=dist/MijiaBar-x.y.z.dmg scripts/generate-appcast.sh
```

## GitHub Pages

站点文件在 `docs/`：`index.html`（英文）和 `zh-CN.html`（简体中文），由 `scripts/gen-site.py` 根据 `site/template.html` 和 `i18n/site/*.json` 生成，不要直接改（繁体中文等页面稳定后再加，译稿在 `i18n/site/drafts/zh-Hant.json`）；图片在 `docs/assets/`（`scripts/site-shots.sh` 生成）；另有 `appcast.xml`。

根页面会按 `?lang=`、访客在语言菜单里的选择、浏览器语言依次决定是否跳转到中文页面（繁体中文浏览器也去简体页面）；旧链接 `index.html?lang=zh` 仍然有效。

仓库设置 → Pages → Source = **Deploy from a branch** → Branch **`main`** / folder **`/docs`**。

首次启用也可用：

```bash
gh api repos/neardws/MijiaBar/pages -X POST \
  -f build_type=legacy \
  -F 'source[branch]=main' \
  -F 'source[path]=/docs'
```

公开地址：<https://www.neardws.com/MijiaBar/>
