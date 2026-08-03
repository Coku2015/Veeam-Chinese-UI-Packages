# Veeam Backup & Replication Web UI 简体中文包 13.0.2.29

此目录仅适用于 Linux Appliance 上的 `veeam-vbr-webui-13.0.2.29-1`。

安装脚本会严格校验以下原始文件的 SHA-256；任一文件不匹配时不会修改系统：

- `/opt/veeam/vbr/GatewayApiService/app/index.html`
- `/opt/veeam/vbr/GatewayApiService/app/assets/index-e21aa407.js`
- `/opt/veeam/vbr/GatewayApiService/app/plugin/plugin.js`
- `/opt/veeam/vbr/wwwroot/oauth/static/lib/languageSelector.js`

## 翻译覆盖率

本包从项目已审校的 `13.1.0.411` 中文目录迁移到旧版 `13.0.2.29`：

- 旧版英文资源：`6102` 条
- 已匹配中文：`5498` 条
- 当前覆盖率：`90.10%`
- 从 13.1 文案变化中审校补充：`77` 条
- 未匹配的旧版专有文本：`604` 条，界面会安全回退为英文

不会显示缺失的翻译 key，也不会把新版命名空间直接写入旧版资源注册表。

## 安装

进入 Veeam Appliance Console 的 root shell 后执行：

```bash
cd /tmp
tar xvf VeeamWebUiZhCN-13.0.2.29-linux.tar.gz
bash VeeamWebUiZhCN-13.0.2.29/linux/install-veeam-webui-zh-cn.sh
```

安装成功后刷新浏览器，在语言菜单中选择“简体中文”。

## 卸载

```bash
cd /tmp
bash VeeamWebUiZhCN-13.0.2.29/linux/uninstall-veeam-webui-zh-cn.sh
```

卸载脚本只会在当前文件哈希与本包安装结果完全一致时还原，避免覆盖 Veeam 升级或其他修改。

## 注意事项

- 这是非官方本地化包，不是 Veeam 官方 hotfix。
- Veeam 升级前请先卸载本包。
- 原始文件备份保存在 `/var/lib/veeam-webui-zh-cn/13.0.2.29/`。
- 不要把此包用于其他 VBR/Web UI build。
