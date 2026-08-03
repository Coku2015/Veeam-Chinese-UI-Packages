#!/usr/bin/env node

const fs = require('fs');
const vm = require('vm');

function usage() {
  console.error(
    'Usage: node tools/generate-vbr-13.0.2.29-catalog.js ' +
      '<VBR-13.0.2.29-plugin.js> <VBR-13.1.0.411-catalog.js> <output.js>',
  );
  process.exit(2);
}

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
    if (char === '"' || char === "'" || char === '`') {
      quote = char;
    } else if (char === open) {
      depth += 1;
    } else if (char === close) {
      depth -= 1;
      if (depth === 0) return text.slice(start, index + 1);
    }
  }
  throw new Error(`Unclosed ${open}${close} expression`);
}

function loadOldEnglishResources(pluginPath) {
  const plugin = fs.readFileSync(pluginPath, 'utf8');
  const marker = 'lX=[{iso:"en",title:"English",flag:"",resources:{';
  const markerPosition = plugin.indexOf(marker);
  if (markerPosition < 0) {
    throw new Error('VBR 13.0.2.29 language registry was not found in plugin.js');
  }
  const arrayStart = plugin.indexOf('[', markerPosition);
  const source = findBalanced(plugin, arrayStart, '[', ']');
  const languages = vm.runInNewContext(`(${source})`, Object.create(null), {
    timeout: 10000,
  });
  const english = languages.find((language) => language.iso === 'en');
  if (!english || !english.resources) {
    throw new Error('English resources were not found in plugin.js');
  }
  return english.resources;
}

function loadNewChineseResources(catalogPath) {
  const context = { globalThis: {} };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(catalogPath, 'utf8'), context, {
    timeout: 10000,
  });
  const catalog = context.globalThis.__VeeamWebUiZhCatalog;
  const sourceTextMap = context.globalThis.__VeeamWebUiZhSourceTextMap;
  if (!catalog || !sourceTextMap) {
    throw new Error('The 13.1 catalog does not expose the expected globals');
  }
  return { catalog, sourceTextMap };
}

function buildKeyMap(catalog) {
  const values = new Map();
  for (const namespace of Object.values(catalog)) {
    for (const [key, value] of Object.entries(namespace)) {
      if (!values.has(key)) values.set(key, new Set());
      values.get(key).add(value);
    }
  }
  return values;
}

function generate(oldEnglish, newChinese, sourceTextMap) {
  const chineseByKey = buildKeyMap(newChinese);
  const catalog = {};
  const usedSourceTextMap = {};
  let total = 0;
  let namespaceAndKeyMatches = 0;
  let keyMatches = 0;
  let sourceTextMatches = 0;

  for (const [namespaceName, namespace] of Object.entries(oldEnglish)) {
    const translatedNamespace = {};
    for (const [key, englishText] of Object.entries(namespace)) {
      total += 1;
      let translated;

      if (newChinese[namespaceName] && key in newChinese[namespaceName]) {
        translated = newChinese[namespaceName][key];
        namespaceAndKeyMatches += 1;
      } else {
        const candidates = chineseByKey.get(key);
        if (candidates && candidates.size === 1) {
          [translated] = candidates;
          keyMatches += 1;
        } else if (Object.prototype.hasOwnProperty.call(sourceTextMap, englishText)) {
          translated = sourceTextMap[englishText];
          sourceTextMatches += 1;
        }
      }

      if (translated !== undefined) {
        translatedNamespace[key] = translated;
        usedSourceTextMap[englishText] = translated;
      }
    }
    if (Object.keys(translatedNamespace).length) {
      catalog[namespaceName] = translatedNamespace;
    }
  }

  const translated = namespaceAndKeyMatches + keyMatches + sourceTextMatches;
  return {
    catalog,
    sourceTextMap: usedSourceTextMap,
    stats: {
      build: '13.0.2.29',
      total,
      translated,
      untranslated: total - translated,
      coveragePercent: Number(((translated * 100) / total).toFixed(2)),
      namespaceAndKeyMatches,
      keyMatches,
      sourceTextMatches,
    },
  };
}

function main() {
  if (process.argv.length !== 5) usage();
  const [, , pluginPath, sourceCatalogPath, outputPath] = process.argv;
  const oldEnglish = loadOldEnglishResources(pluginPath);
  const { catalog: newChinese, sourceTextMap } = loadNewChineseResources(sourceCatalogPath);
  const result = generate(oldEnglish, newChinese, sourceTextMap);

  const output = [
    '/* Generated for VBR Web UI 13.0.2.29 from the reviewed 13.1.0.411 catalog. */',
    `globalThis.__VeeamWebUiZhCatalog = ${JSON.stringify(result.catalog)};`,
    `globalThis.__VeeamWebUiZhSourceTextMap = ${JSON.stringify(result.sourceTextMap)};`,
    `globalThis.__VeeamWebUiZhCoverage = ${JSON.stringify(result.stats)};`,
    '',
  ].join('\n');
  fs.writeFileSync(outputPath, output, 'utf8');
  console.log(JSON.stringify(result.stats, null, 2));
}

main();
