# Web UI 补丁备份与手工还原

本文记录 VBR 13.1.0.411 和 Veeam ONE 13.1.0.7034 安装器的备份范围、卸载逻辑，以及在卸载脚本丢失时的手工还原方法。

## 重要说明：原始备份不作为公共 GitHub 文件发布

安装器生成的 `*.original` 文件来自具体客户服务器的 Veeam 安装目录。它们与产品 build、补丁状态和服务器安装方式绑定，也属于 Veeam 安装介质中的原始 Web UI 资源。因此不能把某一台服务器的原始文件当作通用备份上传到公共仓库：

- 不同服务器的文件可能不同，通用复制会造成错误还原；
- Veeam 升级后，旧 build 的备份不能覆盖新 build 文件；
- 原始 Web UI 文件不应作为本地化包公开分发。

仓库保存的是安装器、校验逻辑和本文的文件映射。真正的备份仍保留在安装目标机的备份目录中。需要离线保存时，应从目标机导出整个备份目录和 manifest，并放在客户自己的受控存储中。

## 1. 安装器备份位置与内容

### VBR Windows 13.1.0.411

备份目录：

```text
C:\ProgramData\VeeamWebUiZhCN\13.1.0.411\
```

文件：

| 备份文件 | 还原到 |
| --- | --- |
| `index.html.original` | `%ProgramFiles%\Veeam\Backup and Replication\BackupWebUI\index.html` |
| `index-BJPSD5I9.js.original` | `%ProgramFiles%\Veeam\Backup and Replication\BackupWebUI\assets\index-BJPSD5I9.js` |
| `plugin.js.original` | `%ProgramFiles%\Veeam\Backup and Replication\BackupWebUI\plugin\plugin.js` |
| `vdpPlugin.js.original` | `%ProgramFiles%\Veeam\Backup and Replication\BackupWebUI\plugin\vdpPlugin.js` |
| `languageSelector.js.original` | `%ProgramFiles%\Veeam\Backup and Replication\Backup\wwwroot\oauth\static\lib\languageSelector.js` |
| `manifest.json` | 仅用于记录原始/补丁后 SHA256，不直接复制到 Web UI 目录 |

补丁新增、卸载时删除的文件：

```text
%ProgramFiles%\Veeam\Backup and Replication\BackupWebUI\assets\veeam-zh-CN-native.js
%ProgramFiles%\Veeam\Backup and Replication\BackupWebUI\assets\veeam-zh-CN-catalog.js
```

如果安装器曾经识别到旧的 login-selector preview，还可能存在：

```text
C:\ProgramData\VeeamWebUiZhNativePreview\13.1.0.411\
```

该目录由安装器用于先还原旧 preview，不是当前正式包的主要备份目录。

### VBR Linux Appliance 13.1.0.411

备份目录：

```text
/var/lib/veeam-webui-zh-cn/13.1.0.411/
```

实际目标路径由 `manifest.env` 记录；标准安装通常为：

| 备份文件 | 标准还原目标 |
| --- | --- |
| `index.html.original` | `/opt/veeam/vbr/BackupWebUI/index.html` |
| `index-BJPSD5I9.js.original` | `/opt/veeam/vbr/BackupWebUI/assets/index-BJPSD5I9.js` |
| `plugin.js.original` | `/opt/veeam/vbr/BackupWebUI/plugin/plugin.js` |
| `vdpPlugin.js.original` | `/opt/veeam/vbr/BackupWebUI/plugin/vdpPlugin.js` |
| `ahv-plugin.js.original` | `/opt/veeam/backup/plugins/ahv/service/wwwroot/plugin/plugin.js` |
| `pve-plugin.js.original` | `/opt/veeam/backup/plugins/pve/service/wwwroot/plugin/plugin.js` |
| `languageSelector.js.original` | `manifest.env` 中的 `LOGIN_SELECTOR_PATH` |
| `manifest.env` | 记录目标路径和原始/补丁后 SHA256 |

卸载时删除：

```text
<WEB_ROOT>/assets/veeam-zh-CN-native.js
<WEB_ROOT>/assets/veeam-zh-CN-catalog.js
```

### Veeam ONE Windows 13.1.0.7034

备份目录：

```text
C:\ProgramData\VeeamWebUiZhCN\VeeamONE-13.1.0.7034\
```

文件：

| 备份文件 | 还原到 |
| --- | --- |
| `index.html.original` | `%ProgramFiles%\Veeam\Veeam ONE\Veeam ONE Reporter Server\Assets\index.html` |
| `plugin.js.original` | `%ProgramFiles%\Veeam\Veeam ONE\Veeam ONE Reporter Server\Assets\plugin\plugin.js` |
| `manifest.json` | 记录原始主 bundle 哈希以及生成文件名 |

Veeam ONE 包不会覆盖原始 `static\js\main.1c26fdf6.js`，而是生成带指纹的新主 bundle 和中文目录 bundle。文件名由 manifest 中的 `GeneratedMainFileName`、`GeneratedCatalogFileName` 给出。卸载时：

1. 还原 `index.html.original`；
2. 还原 `plugin.js.original`；
3. 删除 manifest 中记录的生成主 bundle 和目录 bundle；
4. 验证还原后的哈希；
5. 验证成功后才删除备份目录。

## 2. 卸载脚本的安全逻辑

Windows 和 Linux 卸载器遵循同一原则：

1. 读取 build 对应的备份目录和 manifest；
2. 检查备份文件存在；
3. 先比较当前 Web UI 文件的“补丁后” SHA256；如果文件已经被 Veeam 升级、其他补丁或管理员修改，立即停止，不覆盖任何文件；
4. 将备份复制到临时文件，再使用移动操作替换目标文件，减少中途失败留下半个文件的风险；
5. 删除本补丁生成的中文资源文件；
6. 比较还原后的“原始” SHA256；
7. 只有验证通过后才删除备份目录。

因此，卸载器报错时不要强行继续，也不要用旧 build 的备份覆盖升级后的 Web UI。应先保留备份目录，确认当前 Veeam build，再使用相同 build 的官方修复/安装介质或对应本地化包处理。

## 3. 卸载脚本丢失时的手工还原

手工还原前：

- 在维护窗口操作；停止对应 Web UI/IIS 或 Veeam ONE Reporting Service，避免文件被占用；
- 先复制整个备份目录到安全位置；
- 阅读 manifest，确认 `Original*Sha256` 与目标 build 一致；
- 如果当前文件哈希不等于 manifest 中的 `Patched*Sha256`，停止操作，不要覆盖，说明服务器状态已经变化。

### VBR Windows

以管理员 PowerShell 执行。以下示例使用默认安装路径；如果 manifest 中的实际路径不同，应以服务器实际路径为准：

```powershell
$backup = 'C:\ProgramData\VeeamWebUiZhCN\13.1.0.411'
$root = Join-Path $env:ProgramFiles 'Veeam\Backup and Replication\BackupWebUI'
$login = Join-Path $env:ProgramFiles 'Veeam\Backup and Replication\Backup\wwwroot\oauth\static\lib\languageSelector.js'

# 先检查备份和 manifest；不要跳过这一步
$manifest = Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw | ConvertFrom-Json
Get-ChildItem -LiteralPath $backup

function Assert-Hash([string]$Path, [string]$Expected, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path) -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Expected.ToLowerInvariant()) {
        throw "$Label does not match the patched hash in manifest. Stop; do not overwrite it."
    }
}

# 只有当前文件仍是本包写入的文件时才继续；升级后会在这里停止
Assert-Hash (Join-Path $root 'index.html') $manifest.PatchedHtmlSha256 'index.html'
Assert-Hash (Join-Path $root 'assets\index-BJPSD5I9.js') $manifest.PatchedIndexSha256 'main Web UI bundle'
Assert-Hash (Join-Path $root 'plugin\plugin.js') $manifest.PatchedPluginSha256 'plugin.js'
Assert-Hash (Join-Path $root 'plugin\vdpPlugin.js') $manifest.PatchedVdpPluginSha256 'vdpPlugin.js'
Assert-Hash $login $manifest.PatchedLoginSelectorSha256 'languageSelector.js'

# 确认当前状态后，再复制原始文件
Copy-Item -LiteralPath (Join-Path $backup 'index.html.original') -Destination (Join-Path $root 'index.html') -Force
Copy-Item -LiteralPath (Join-Path $backup 'index-BJPSD5I9.js.original') -Destination (Join-Path $root 'assets\index-BJPSD5I9.js') -Force
Copy-Item -LiteralPath (Join-Path $backup 'plugin.js.original') -Destination (Join-Path $root 'plugin\plugin.js') -Force
Copy-Item -LiteralPath (Join-Path $backup 'vdpPlugin.js.original') -Destination (Join-Path $root 'plugin\vdpPlugin.js') -Force
Copy-Item -LiteralPath (Join-Path $backup 'languageSelector.js.original') -Destination $login -Force

Remove-Item -LiteralPath (Join-Path $root 'assets\veeam-zh-CN-native.js') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $root 'assets\veeam-zh-CN-catalog.js') -Force -ErrorAction SilentlyContinue
```

复制完成后，用 `Get-FileHash -Algorithm SHA256` 对照 manifest 中的 `Original*Sha256`。如果哈希不一致，立即停止，不要删除备份目录。

### VBR Linux Appliance

以 root 身份执行。`manifest.env` 是安装器生成的本地文件，执行前应先查看其内容并确认没有被修改：

```bash
BACKUP_ROOT=/var/lib/veeam-webui-zh-cn/13.1.0.411
sed -n '1,240p' "${BACKUP_ROOT}/manifest.env"

# 仅在确认 manifest 和当前 build 正确后执行
set -a
. "${BACKUP_ROOT}/manifest.env"
set +a

sha256_file() { sha256sum "$1" | awk '{print tolower($1)}'; }
[[ "$(sha256_file "${HTML_PATH}")" == "${PATCHED_HTML_SHA256}" ]] || { echo 'index.html is not the package output; stop.' >&2; exit 1; }
[[ "$(sha256_file "${INDEX_PATH}")" == "${PATCHED_INDEX_SHA256}" ]] || { echo 'main bundle is not the package output; stop.' >&2; exit 1; }
[[ "$(sha256_file "${PLUGIN_PATH}")" == "${PATCHED_PLUGIN_SHA256}" ]] || { echo 'plugin.js is not the package output; stop.' >&2; exit 1; }
[[ "$(sha256_file "${VDP_PLUGIN_PATH}")" == "${PATCHED_VDP_PLUGIN_SHA256}" ]] || { echo 'vdpPlugin.js is not the package output; stop.' >&2; exit 1; }
[[ "$(sha256_file "${AHV_PLUGIN_PATH}")" == "${PATCHED_AHV_PLUGIN_SHA256}" ]] || { echo 'AHV plugin is not the package output; stop.' >&2; exit 1; }
[[ "$(sha256_file "${PVE_PLUGIN_PATH}")" == "${PATCHED_PVE_PLUGIN_SHA256}" ]] || { echo 'PVE plugin is not the package output; stop.' >&2; exit 1; }
[[ "$(sha256_file "${LOGIN_SELECTOR_PATH}")" == "${PATCHED_LOGIN_SELECTOR_SHA256}" ]] || { echo 'language selector is not the package output; stop.' >&2; exit 1; }

cp -p "${BACKUP_HTML_PATH}" "${HTML_PATH}"
cp -p "${BACKUP_INDEX_PATH}" "${INDEX_PATH}"
cp -p "${BACKUP_PLUGIN_PATH}" "${PLUGIN_PATH}"
cp -p "${BACKUP_VDP_PLUGIN_PATH}" "${VDP_PLUGIN_PATH}"
cp -p "${BACKUP_AHV_PLUGIN_PATH}" "${AHV_PLUGIN_PATH}"
cp -p "${BACKUP_PVE_PLUGIN_PATH}" "${PVE_PLUGIN_PATH}"
cp -p "${BACKUP_LOGIN_SELECTOR_PATH}" "${LOGIN_SELECTOR_PATH}"

rm -f "${NATIVE_ASSET_PATH}" "${CATALOG_ASSET_PATH}"
```

完成后，对所有目标文件运行 `sha256sum`，逐项核对 `ORIGINAL_*_SHA256`。如果任意一项不一致，保留备份目录并使用官方 build 修复流程。

### Veeam ONE Windows

以管理员 PowerShell 执行。Veeam ONE 的原始 main bundle 没有被复制到备份目录；它始终保留在 `static\js\main.1c26fdf6.js`，manifest 只保存其原始哈希。因此手工还原只恢复 HTML 和 plugin，并删除 manifest 指定的生成文件：

```powershell
$backup = 'C:\ProgramData\VeeamWebUiZhCN\VeeamONE-13.1.0.7034'
$assetRoot = Join-Path $env:ProgramFiles 'Veeam\Veeam ONE\Veeam ONE Reporter Server\Assets'
$static = Join-Path $assetRoot 'static\js'
$manifest = Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw | ConvertFrom-Json

function Assert-Hash([string]$Path, [string]$Expected, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path) -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Expected.ToLowerInvariant()) {
        throw "$Label does not match the patched hash in manifest. Stop; do not overwrite it."
    }
}

$htmlPath = Join-Path $assetRoot 'index.html'
$pluginPath = Join-Path $assetRoot 'plugin\plugin.js'
$generatedMainPath = Join-Path $static $manifest.GeneratedMainFileName
$generatedCatalogPath = Join-Path $static $manifest.GeneratedCatalogFileName
Assert-Hash $htmlPath $manifest.PatchedHtmlSha256 'index.html'
Assert-Hash $pluginPath $manifest.PatchedPluginSha256 'plugin.js'
Assert-Hash $generatedMainPath $manifest.GeneratedMainSha256 'generated main bundle'
Assert-Hash $generatedCatalogPath $manifest.GeneratedCatalogSha256 'generated Chinese catalog'

Copy-Item -LiteralPath (Join-Path $backup 'index.html.original') -Destination $htmlPath -Force
Copy-Item -LiteralPath (Join-Path $backup 'plugin.js.original') -Destination $pluginPath -Force
Remove-Item -LiteralPath $generatedMainPath -Force
Remove-Item -LiteralPath $generatedCatalogPath -Force

Get-FileHash -LiteralPath $htmlPath -Algorithm SHA256
Get-FileHash -LiteralPath $pluginPath -Algorithm SHA256
```

最后确认 `static\js\main.1c26fdf6.js` 的哈希仍等于 `manifest.OriginalMainSha256`。如果该文件缺失或哈希不一致，不要用其他服务器的文件替换，应先用同一 build 的 Veeam ONE 安装介质执行修复。

## 4. 如何导出一份私有备份

如果客户希望把备份放到自己的制品库或工单附件中，导出整个版本目录，而不是只导出某一个 `*.original` 文件：

```powershell
$src = 'C:\ProgramData\VeeamWebUiZhCN\13.1.0.411'
$dst = 'D:\Private-Veeam-Backups\VBR-13.1.0.411'
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
Get-ChildItem -LiteralPath $dst -File -Recurse | Get-FileHash -Algorithm SHA256 |
    Export-Csv -NoTypeInformation -Path (Join-Path $dst 'export-sha256.csv')
```

Linux 可使用：

```bash
install -d -m 700 /root/private-veeam-backups/VBR-13.1.0.411
cp -a /var/lib/veeam-webui-zh-cn/13.1.0.411/. /root/private-veeam-backups/VBR-13.1.0.411/
find /root/private-veeam-backups/VBR-13.1.0.411 -type f -print0 |
  xargs -0 sha256sum > /root/private-veeam-backups/VBR-13.1.0.411/export-sha256.txt
```

导出的备份应存放在客户自己的加密存储中。不要把 `ProgramData`、`/var/lib` 中的原始备份文件提交到公共 GitHub。

## 5. 升级时的处理原则

- Veeam 升级前先卸载本地化包，并确认卸载后的原始哈希验证成功；
- 升级完成后，下载与新 build 完全匹配的本地化包重新安装；
- 如果升级已经发生而旧包卸载失败，保留旧备份目录，不要强制覆盖；
- 先使用 Veeam 官方修复/安装介质恢复新 build，再处理本地化包；
- 不要把一台服务器导出的原始文件用于另一台服务器，也不要跨 build 还原。
