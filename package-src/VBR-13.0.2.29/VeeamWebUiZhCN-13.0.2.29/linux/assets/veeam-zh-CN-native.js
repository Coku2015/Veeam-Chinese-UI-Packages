/*
 * Chinese presentation layer for the VBR 13.0.2.29 Simplified Chinese package.
 * It is active only when the patched Veeam language selector is set to zh-CN.
 */
(function () {
  'use strict';

  var languageKey = 'localization:language';
  var pluginLanguageKey = 'localization:language';
  var dictionary = new Map([
    ['Veeam Backup & Replication', 'Veeam 备份与复制'],
    ['Home', '主页'],
    ['Overview', '概览'],
    ['Jobs', '作业'],
    ['Backups', '备份'],
    ['Running Sessions', '正在运行的会话'],
    ['Configuration', '配置'],
    ['Analytics', '分析'],
    ['Reports', '报告'],
    ['Dashboards', '仪表板'],
    ['Alarms Overview', '告警概览'],
    ['Infrastructure', '基础架构'],
    ['Managed Servers', '受管服务器'],
    ['Repositories', '存储库'],
    ['Repository', '存储库'],
    ['Proxies', '代理服务器'],
    ['Credentials', '凭据'],
    ['Roles and Users', '角色和用户'],
    ['Settings', '设置'],
    ['Security', '安全'],
    ['Malware Detection', '恶意软件检测'],
    ['License Information', '许可证信息'],
    ['Update Settings', '更新设置'],
    ['Appearance', '外观'],
    ['Log out', '退出登录'],
    ['Refresh', '刷新'],
    ['Search', '搜索'],
    ['Filter', '筛选'],
    ['Clear filters', '清除筛选'],
    ['Add', '添加'],
    ['Edit', '编辑'],
    ['Delete', '删除'],
    ['Remove', '移除'],
    ['Save', '保存'],
    ['Cancel', '取消'],
    ['Close', '关闭'],
    ['Retry', '重试'],
    ['Back', '返回'],
    ['Next', '下一步'],
    ['Previous', '上一步'],
    ['Finish', '完成'],
    ['Done', '完成'],
    ['Yes', '是'],
    ['No', '否'],
    ['Loading...', '正在加载…'],
    ['No items to display', '没有可显示的项目'],
    ['No data available', '没有可用数据'],
    ['Status', '状态'],
    ['Type', '类型'],
    ['Name', '名称'],
    ['Description', '说明'],
    ['Details', '详细信息'],
    ['Actions', '操作'],
    ['Success', '成功'],
    ['Warning', '警告'],
    ['Error', '错误'],
    ['Failed', '失败'],
    ['Running', '正在运行'],
    ['Stopped', '已停止'],
    ['Enabled', '已启用'],
    ['Disabled', '已禁用'],
    ['Help', '帮助'],
    ['About', '关于'],
    ['Notifications', '通知'],
    ['Select all', '全选'],
    ['Deselect all', '取消全选'],
    ['Column settings', '列设置'],
    ['Show more', '显示更多'],
    ['Show less', '收起'],
    ['Copy', '复制'],
    ['Download', '下载'],
    ['Upload', '上传'],
    ['Export', '导出'],
    ['Import', '导入'],
    ['Confirm', '确认'],
    ['Are you sure?', '确定要继续吗？'],
    ['Specify whether you want to restore VMs to the original location or to a new one, or with different settings.', '指定是要将虚拟机还原到原始位置、新位置，还是使用不同设置还原。'],
    ['Restore to original location', '还原到原始位置'],
    ['Quickly restore the selected VMs to their original location, with the same name and settings as the original VMs.', '快速将所选虚拟机还原到其原始位置，并使用与原始虚拟机相同的名称和设置。'],
    ['Restore to new location', '还原到新位置'],
    ['Perform additional configuration steps to restore the selected VMs to a new location or to use settings that differ from the original settings.', '执行其他配置步骤，将所选虚拟机还原到新位置，或使用不同于原始设置的设置。']
  ]);
  var generatedSourceMap = globalThis.__VeeamWebUiZhSourceTextMap || {};
  Object.keys(generatedSourceMap).forEach(function (source) {
    if (!dictionary.has(source)) dictionary.set(source, generatedSourceMap[source]);
  });

  var skipTags = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEXTAREA', 'CODE', 'PRE']);
  var attributeNames = ['aria-label', 'placeholder', 'title', 'alt'];
  var started = false;
  var lastActive = false;

  function active() {
    try {
      var storedLanguage = window.localStorage.getItem(languageKey);
      return storedLanguage === 'zh-CN' || storedLanguage === '"zh-CN"';
    } catch (_) {
      return false;
    }
  }

  function syncPluginLanguage() {
    try {
      if (active()) {
        window.localStorage.setItem(pluginLanguageKey, JSON.stringify('zh-CN'));
      }
    } catch (_) {
      // Ignore storage errors. The DOM fallback below still handles visible text.
    }
  }

  // This script is loaded before the Veeam main module and plugin bundles.
  // Sync the plugin i18n key immediately so plugin wizards initialize with zh-CN
  // resources instead of rendering English first and relying on DOM fallback later.
  syncPluginLanguage();

  function translate(value) {
    if (typeof value !== 'string') return null;
    var match = value.match(/^(\s*)(.*?)(\s*)$/s);
    if (!match) return null;
    var core = match[2];
    var translated = dictionary.get(core);
    if (!translated && /:$/u.test(core)) {
      var withoutColon = core.replace(/:$/u, '');
      var colonTranslation = dictionary.get(withoutColon);
      if (colonTranslation) translated = /：$/u.test(colonTranslation) ? colonTranslation : colonTranslation + '：';
    }
    return translated ? match[1] + translated + match[3] : null;
  }

  function translateTextNode(node) {
    if (!active() || !node.parentElement || skipTags.has(node.parentElement.tagName)) return;
    var translated = translate(node.nodeValue);
    if (translated) node.nodeValue = translated;
  }

  function translateElement(element) {
    if (!active() || !(element instanceof Element) || skipTags.has(element.tagName)) return;
    attributeNames.forEach(function (name) {
      var translated = translate(element.getAttribute(name));
      if (translated) element.setAttribute(name, translated);
    });
    if (element instanceof HTMLInputElement && /^(button|submit|reset)$/i.test(element.type)) {
      var value = translate(element.value);
      if (value) element.value = value;
    }
  }

  function translateTree(root) {
    if (!active() || !root) return;
    if (root.nodeType === Node.TEXT_NODE) {
      translateTextNode(root);
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_NODE) return;
    var elements = root.querySelectorAll ? [root].concat(Array.from(root.querySelectorAll('*'))) : [];
    elements.forEach(translateElement);
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    var node;
    while ((node = walker.nextNode())) translateTextNode(node);
  }

  function addBadge() {
    return;
  }

  function start() {
    if (started || !active()) return;
    started = true;
    lastActive = true;
    syncPluginLanguage();
    document.documentElement.lang = 'zh-CN';
    translateTree(document);
    addBadge();
    new MutationObserver(function (changes) {
      changes.forEach(function (change) {
        if (change.type === 'characterData') translateTextNode(change.target);
        change.addedNodes.forEach(translateTree);
      });
      addBadge();
    }).observe(document.documentElement, { childList: true, characterData: true, subtree: true });
    setInterval(function () {
      var isActive = active();
      if (isActive) {
        syncPluginLanguage();
        document.documentElement.lang = 'zh-CN';
        translateTree(document);
      }
      lastActive = isActive;
    }, 750);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();
