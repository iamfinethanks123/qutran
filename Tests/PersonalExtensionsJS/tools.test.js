// Run with: node --test Tests/PersonalExtensionsJS/tools.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const t = require('../../PersonalExtensions/personal-text-tools.openclipext/lib/tools.js');

test('fixLineBreaks joins wrapped English lines and keeps paragraphs', () => {
  const input = 'This is a sen-\ntence broken\nacross lines.\n\nSecond paragraph\nhere.';
  assert.equal(t.fixLineBreaks(input), 'This is a sentence broken across lines.\n\nSecond paragraph here.');
});

test('fixLineBreaks joins CJK lines without spaces', () => {
  assert.equal(t.fixLineBreaks('離線翻譯可以\n在沒有網路的\n情況下使用。'), '離線翻譯可以在沒有網路的情況下使用。');
});

test('countText reports CJK characters, words and characters', () => {
  assert.equal(t.countText('Hello world 你好'), '2 字 · 2 詞 · 12 字元');
  assert.equal(t.countText('abc'), '1 詞 · 3 字元');
});

test('case transforms', () => {
  assert.equal(t.upper('Hello'), 'HELLO');
  assert.equal(t.lower('Hello'), 'hello');
  assert.equal(t.titleCase('the quick brown fox'), 'The Quick Brown Fox');
  assert.equal(t.snakeCase('Hello World fooBar'), 'hello_world_foo_bar');
  assert.equal(t.camelCase('hello world-foo_bar'), 'helloWorldFooBar');
});

test('JSON format and minify', () => {
  assert.equal(t.formatJSON('{"a":1,"b":[2]}'), '{\n  "a": 1,\n  "b": [\n    2\n  ]\n}');
  assert.equal(t.minifyJSON('{ "a" : 1 }'), '{"a":1}');
  assert.throws(() => t.formatJSON('{oops'));
});

test('Base64 round-trips UTF-8 including Chinese and emoji', () => {
  for (const s of ['', 'a', 'ab', 'abc', 'Hello, 世界', '繁體中文 😀']) {
    assert.equal(t.base64Decode(t.base64Encode(s)), s);
    assert.equal(t.base64Encode(s), Buffer.from(s, 'utf8').toString('base64'));
  }
  assert.throws(() => t.base64Decode('not base64!'));
});

test('URL encode and decode', () => {
  assert.equal(t.urlEncode('a b&c=中'), 'a%20b%26c%3D%E4%B8%AD');
  assert.equal(t.urlDecode('a%20b+c%E4%B8%AD'), 'a b c中');
});
