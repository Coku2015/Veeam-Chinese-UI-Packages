#!/usr/bin/env node

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const repositoryRoot = path.resolve(__dirname, '..');
const pluginPath = path.resolve(repositoryRoot, '../current-server/plugin.js');
const catalogPath = path.join(
  repositoryRoot,
  'package-src/VBR-13.0.2.29/VeeamWebUiZhCN-13.0.2.29/linux/assets/veeam-zh-CN-catalog.js',
);

function findBalanced(text, start, open, close) {
  let depth = 0;
  let quote = '';
  let escaped = false;

  for (let index = start; index < text.length; index += 1) {
    const char = text[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (char === '\\') escaped = true;
      else if (char === quote) quote = '';
      continue;
    }
    if (char === '"' || char === "'" || char === '`') quote = char;
    else if (char === open) depth += 1;
    else if (char === close) {
      depth -= 1;
      if (depth === 0) return text.slice(start, index + 1);
    }
  }
  throw new Error(`Unclosed ${open}${close} expression`);
}

function loadEnglishResources() {
  const plugin = fs.readFileSync(pluginPath, 'utf8');
  const marker = 'lX=[{iso:"en",title:"English",flag:"",resources:{';
  const markerPosition = plugin.indexOf(marker);
  assert.notStrictEqual(markerPosition, -1, 'English language registry was not found');
  const arrayStart = plugin.indexOf('[', markerPosition);
  const source = findBalanced(plugin, arrayStart, '[', ']');
  const languages = vm.runInNewContext(`(${source})`, Object.create(null));
  return languages.find((language) => language.iso === 'en').resources;
}

function loadCatalog() {
  const context = { globalThis: {} };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(catalogPath, 'utf8'), context);
  return context.globalThis;
}

function extractPlaceholders(text) {
  return [...text.matchAll(/\{\{[^{}]+\}\}|\{[^{}]+\}|%\d*\$?[a-z]|\[\[[^\]]+\]\]/gi)]
    .map((match) => match[0])
    .sort();
}

const englishResources = loadEnglishResources();
const { __VeeamWebUiZhCatalog: catalog, __VeeamWebUiZhSourceTextMap: sourceTextMap } =
  loadCatalog();
const resourceMismatches = [];

for (const [namespaceName, namespace] of Object.entries(catalog)) {
  for (const [key, chineseText] of Object.entries(namespace)) {
    const englishText = englishResources[namespaceName]?.[key];
    assert.notStrictEqual(
      englishText,
      undefined,
      `Generated resource does not exist in VBR 13.0: ${namespaceName}::${key}`,
    );
    const englishPlaceholders = extractPlaceholders(englishText);
    const chinesePlaceholders = extractPlaceholders(chineseText);
    if (JSON.stringify(englishPlaceholders) !== JSON.stringify(chinesePlaceholders)) {
      resourceMismatches.push({
        resourceId: `${namespaceName}::${key}`,
        englishText,
        chineseText,
        englishPlaceholders,
        chinesePlaceholders,
      });
    }
  }
}

const sourceMismatches = [];
for (const [englishText, chineseText] of Object.entries(sourceTextMap)) {
  const englishPlaceholders = extractPlaceholders(englishText);
  const chinesePlaceholders = extractPlaceholders(chineseText);
  if (JSON.stringify(englishPlaceholders) !== JSON.stringify(chinesePlaceholders)) {
    sourceMismatches.push({
      englishText,
      chineseText,
      englishPlaceholders,
      chinesePlaceholders,
    });
  }
}

assert.deepStrictEqual(resourceMismatches, [], JSON.stringify(resourceMismatches, null, 2));
assert.deepStrictEqual(sourceMismatches, [], JSON.stringify(sourceMismatches, null, 2));

const expectedTranslations = {
  'appFLR::appFLR|browse|title': '浏览',
  'appFLR::appFLR|audit|title': '审计',
  'inventoryTreeWithSearch::inventoryTreeWithSearch|search|placeholder|host':
    '在 {{hostName}} 上输入对象名称',
  'proxiesPage::proxiesPage|removeDialog|text': '是否移除代理/Worker？',
  'emailOptionsPage::emailOptionsPage|field|subject|placeholder': '指定所发送邮件的主题',
};

for (const [resourceId, expected] of Object.entries(expectedTranslations)) {
  const separator = resourceId.indexOf('::');
  const namespaceName = resourceId.slice(0, separator);
  const key = resourceId.slice(separator + 2);
  assert.strictEqual(catalog[namespaceName][key], expected, resourceId);
}

console.log(
  JSON.stringify(
    {
      resourceMismatchCount: resourceMismatches.length,
      sourceMismatchCount: sourceMismatches.length,
      regressionTranslationsChecked: Object.keys(expectedTranslations).length,
    },
    null,
    2,
  ),
);
