#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { DOMParser, XMLSerializer } from '@xmldom/xmldom';
import { render } from 'pele';

// Resolve Pele's CSS variables for SVG viewers such as Emacs/librsvg.
// Walk elements so locally scoped font-weight variables retain their scope.
export function standalone(svg) {
  const doc = new DOMParser().parseFromString(svg, 'image/svg+xml');
  function walk(el, inherited = {}) {
    const vars = { ...inherited };
    const style = el.getAttribute('style') || '';
    for (const declaration of style.split(';')) {
      const colon = declaration.indexOf(':');
      if (colon < 0) continue;
      const key = declaration.slice(0, colon).trim();
      if (key.startsWith('--')) vars[key] = declaration.slice(colon + 1).trim();
    }
    function resolve(value, depth = 0) {
      if (depth > 20) throw new Error('CSS variable nesting exceeds 20 levels');
      return value.replace(/var\((--[\w-]+)(?:,([^()]*))?\)/g, (_, key, fallback) => {
        const replacement = vars[key] ?? fallback;
        if (replacement === undefined) throw new Error(`Unresolved SVG variable: ${key}`);
        return resolve(replacement, depth + 1);
      });
    }
    for (const attr of Array.from(el.attributes)) {
      if (attr.name === 'style') {
        const concrete = style.split(';').filter(s => !s.trim().startsWith('--')).join(';');
        el.setAttribute('style', resolve(concrete));
      } else {
        el.setAttribute(attr.name, resolve(attr.value));
      }
    }
    for (const child of Array.from(el.childNodes)) {
      if (child.nodeType === 1) walk(child, vars);
    }
  }
  walk(doc.documentElement);
  return new XMLSerializer().serializeToString(doc);
}

try {
  const options = JSON.parse(process.argv[2] || '{}');
  const source = readFileSync(0, 'utf8');
  const result = render(source, { ...options, responsive: false, autoDirection: false });
  process.stdout.write(standalone(result.svg));
} catch (error) {
  process.stderr.write(`Pele: ${error.message}\n`);
  process.exitCode = 1;
}
