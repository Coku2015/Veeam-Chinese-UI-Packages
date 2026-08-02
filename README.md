# Veeam 中文 UI 本地化包

这里存放 Veeam 产品 Web UI 的非官方简体中文本地化包。

当前已发布：

- Veeam Backup & Replication Web UI 简体中文包

未来如果制作 Veeam ONE、Veeam Recovery Orchestrator 等产品的中文 UI 包，也会按产品分类放在本仓库中。

## 目录结构

```text
VBR WebUI Chinese Package/
└── VBR-13.1.0.411/
    ├── VeeamWebUiZhCN-13.1.0.411-linux.tar.gz
    ├── VeeamWebUiZhCN-13.1.0.411-windows.zip
    ├── VeeamWebUiZhCN-13.1.0.411-full.zip
    └── SHA256SUMS-13.1.0.411.txt
```

目录中的版本号必须与 Veeam Backup & Replication Web UI build 匹配。请不要把不同 build 的包混用。

## VBR Web UI 中文包说明

此包会在 Veeam Backup & Replication Web UI 中增加“简体中文”语言选项，不覆盖原有 English、German、French、Japanese。

当前支持版本：

| 产品 | Web UI build | 目录 |
| --- | --- | --- |
| Veeam Backup & Replication | `13.1.0.411` | `VBR WebUI Chinese Package/VBR-13.1.0.411/` |

## Linux Appliance 安装

标准流程：

1. 进入 Veeam Appliance Console。
2. 选择 `Enable SSH server`，启用 SSH。
3. 在本机通过 `scp` 将安装包上传到 Appliance 的 `/tmp/` 目录。
4. 回到 Veeam Appliance Console，选择 `Enter shell` 进入 Shell。
5. 在 `/tmp` 中解压并执行安装脚本。

上传安装包：

```bash
scp VeeamWebUiZhCN-13.1.0.411-linux.tar.gz veeamadmin@10.10.1.211:/tmp/
```

其中 `10.10.1.211` 请替换为你的 Veeam Backup Server / Linux Appliance IP。

进入 Appliance Shell 后执行：

```bash
cd /tmp
tar xvf VeeamWebUiZhCN-13.1.0.411-linux.tar.gz
bash VeeamWebUiZhCN-13.1.0.411/linux/install-veeam-webui-zh-cn.sh
```

安装后刷新浏览器，选择“简体中文”。

卸载还原：

```bash
cd /tmp
bash VeeamWebUiZhCN-13.1.0.411/linux/uninstall-veeam-webui-zh-cn.sh
```

### Linux Appliance 操作截图

启用 SSH Server：

![Enable SSH server](screenshots/Xnip2026-08-02_19-24-46.jpg)

进入 Shell：

![Enter shell](screenshots/Xnip2026-08-02_19-21-44.jpg)

Web UI 简体中文效果：

![VBR Web UI Chinese 1](screenshots/Xnip2026-08-02_17-27-51.jpg)

![VBR Web UI Chinese 2](screenshots/Xnip2026-08-02_17-28-09.jpg)

![VBR Web UI Chinese 3](screenshots/Xnip2026-08-02_17-28-21.jpg)

![VBR Web UI Chinese 4](screenshots/Xnip2026-08-02_17-37-24.jpg)

![VBR Web UI Chinese 5](screenshots/Xnip2026-08-02_17-40-09.jpg)

![VBR Web UI Chinese 6](screenshots/Xnip2026-08-02_17-40-44.jpg)

## Windows 安装

在 Veeam Backup Server 上，以管理员身份打开 PowerShell：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\Users\Administrator\Downloads\VeeamWebUiZhCN-13.1.0.411\windows
.\Install-VeeamWebUiZhCN.ps1
```

安装后浏览器按 `Ctrl+F5` 强制刷新，然后选择“简体中文”。

卸载还原：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\Users\Administrator\Downloads\VeeamWebUiZhCN-13.1.0.411\windows
.\Uninstall-VeeamWebUiZhCN.ps1
```

## 校验文件

每个版本目录中提供 `SHA256SUMS-<build>.txt`，可用于校验下载文件完整性。

Linux/macOS：

```bash
shasum -a 256 -c SHA256SUMS-13.1.0.411.txt
```

Windows PowerShell 可使用：

```powershell
Get-FileHash .\VeeamWebUiZhCN-13.1.0.411-windows.zip -Algorithm SHA256
```

## 注意事项

- 这是非官方本地化包，不是 Veeam 官方 hotfix。
- 安装前请确认 Veeam Web UI build 与目录版本一致。
- 建议在升级 Veeam 前先卸载本地化包，升级完成后再安装匹配新 build 的中文包。
- 安装脚本会备份被修改的 Web UI 静态文件，卸载脚本会校验并还原。
- 如果安装脚本提示 hash 不匹配，说明 Veeam 文件可能已升级或被修改，请不要强行安装不匹配版本。
