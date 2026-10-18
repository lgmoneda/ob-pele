import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { DOMParser } from '@xmldom/xmldom';
const render = (input) => spawnSync(process.execPath, ['renderer.mjs'], { input, encoding: 'utf8' });
for (const [name, source] of Object.entries({
  flowchart: 'flowchart LR\n A[Idea] --> B[Draft]',
  sequence: 'sequenceDiagram\n Alice->>Bob: Hello',
  mindmap: 'mindmap\n  root((Notes))\n    Books\n    Projects',
  pie: 'pie\n "A": 40\n "B": 60',
  gantt: 'gantt\n dateFormat YYYY-MM-DD\n section Work\n Draft :2026-10-17, 3d',
  literal: 'flowchart LR\n A["var(--literal)"] --> B["Olá 世界"]',
})) {
  test(`renders ${name} as standalone SVG`, () => {
    const result = render(source);
    assert.equal(result.status, 0, result.stderr);
    const doc = new DOMParser().parseFromString(result.stdout, 'image/svg+xml');
    assert.equal(doc.documentElement.tagName, 'svg');
    assert.ok(Number(doc.documentElement.getAttribute('width')) > 0);
    for (const el of Array.from(doc.getElementsByTagName('*'))) {
      for (const attr of Array.from(el.attributes)) assert.ok(!attr.value.includes('var(--'), attr.value);
    }
    if (name === 'literal') assert.ok(result.stdout.includes('var(--literal)'));
  });
}
test('invalid diagram reports failure without SVG', () => {
  const result = render('this is not a diagram');
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /Pele:/);
});
