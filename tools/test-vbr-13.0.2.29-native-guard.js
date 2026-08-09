#!/usr/bin/env node

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const repositoryRoot = path.resolve(__dirname, '..');
const nativeAssetPath = path.join(
  repositoryRoot,
  'package-src/VBR-13.0.2.29/VeeamWebUiZhCN-13.0.2.29/linux/assets/veeam-zh-CN-native.js'
);
const nativeSource = fs.readFileSync(nativeAssetPath, 'utf8');

function runCase(initialText, generatedSourceMap) {
  let currentText = initialText;
  let textWrites = 0;
  let observerCallback;

  class FakeElement {
    constructor() {
      this.tagName = 'DIV';
    }

    getAttribute() {
      return null;
    }

    setAttribute() {
      throw new Error('The regression fixture must not write element attributes.');
    }
  }

  class FakeInputElement extends FakeElement {}

  const textNode = {
    nodeType: 3,
    parentElement: new FakeElement()
  };
  Object.defineProperty(textNode, 'nodeValue', {
    get() {
      return currentText;
    },
    set(value) {
      textWrites += 1;
      currentText = value;
    }
  });

  const root = {
    nodeType: 9,
    lang: 'en',
    querySelectorAll() {
      return [];
    }
  };
  const document = {
    readyState: 'complete',
    documentElement: root,
    createTreeWalker() {
      let returned = false;
      return {
        nextNode() {
          if (returned) return null;
          returned = true;
          return textNode;
        }
      };
    }
  };

  class FakeMutationObserver {
    constructor(callback) {
      observerCallback = callback;
    }

    observe() {}
  }

  const localStorage = {
    getItem(key) {
      return key === 'localization:language' ? '"zh-CN"' : null;
    },
    setItem() {}
  };

  const context = {
    Element: FakeElement,
    HTMLInputElement: FakeInputElement,
    MutationObserver: FakeMutationObserver,
    Node: { TEXT_NODE: 3, ELEMENT_NODE: 1, DOCUMENT_NODE: 9 },
    NodeFilter: { SHOW_TEXT: 4 },
    document,
    localStorage,
    window: { localStorage },
    __VeeamWebUiZhSourceTextMap: generatedSourceMap,
    setInterval() {
      throw new Error('The native compatibility layer must not start a polling interval.');
    }
  };
  context.globalThis = context;

  vm.createContext(context);
  vm.runInContext(nativeSource, context, { filename: nativeAssetPath, timeout: 1000 });

  if (observerCallback) {
    observerCallback([{ type: 'characterData', target: textNode, addedNodes: [] }]);
  }

  return { text: currentText, writes: textWrites };
}

const identityResult = runCase('Veeam Intelligence', {
  'Veeam Intelligence': 'Veeam Intelligence'
});
if (identityResult.text !== 'Veeam Intelligence' || identityResult.writes !== 0) {
  throw new Error(`Identity translation wrote the text node: ${JSON.stringify(identityResult)}`);
}

const translatedResult = runCase('Home', {});
if (translatedResult.text !== '主页' || translatedResult.writes !== 1) {
  throw new Error(`Expected one effective translation write: ${JSON.stringify(translatedResult)}`);
}

console.log('NATIVE_GUARD_TEST=ok');
