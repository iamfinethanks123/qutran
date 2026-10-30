// Pure text transforms shared by every action in this package.
// Runs in JavaScriptCore (no btoa/atob/TextEncoder), so UTF-8 and Base64 are implemented here.

function wordsOf(text) {
  return text
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .split(/[^A-Za-z0-9À-ɏ]+/)
    .filter(Boolean);
}

// Joins lines broken mid-paragraph (typical of PDF copies); blank lines stay paragraph breaks.
// CJK lines join without a space; hyphenated English words are rejoined.
function fixLineBreaks(text) {
  const paragraphs = text.replace(/\r\n?/g, '\n').split(/\n\s*\n/);
  return paragraphs.map(function (paragraph) {
    const lines = paragraph.split('\n').map(function (l) { return l.trim(); }).filter(Boolean);
    let out = '';
    lines.forEach(function (line) {
      if (!out) { out = line; return; }
      if (/[A-Za-z]-$/.test(out) && /^[a-z]/.test(line)) { out = out.slice(0, -1) + line; return; }
      const cjkJoin = /[　-鿿＀-￯]$/.test(out) || /^[　-鿿＀-￯]/.test(line);
      out += (cjkJoin ? '' : ' ') + line;
    });
    return out;
  }).join('\n\n');
}

function countText(text) {
  const cjk = (text.match(/[㐀-鿿豈-﫿぀-ヿ가-힯]/g) || []).length;
  const words = (text.replace(/[㐀-鿿豈-﫿぀-ヿ가-힯]/g, ' ').match(/[A-Za-z0-9À-ɏ'’-]+/g) || []).length;
  const chars = Array.from(text.replace(/\s/g, '')).length;
  const parts = [];
  if (cjk) parts.push(cjk + ' 字');
  if (words) parts.push(words + ' 詞');
  parts.push(chars + ' 字元');
  return parts.join(' · ');
}

const upper = function (t) { return t.toUpperCase(); };
const lower = function (t) { return t.toLowerCase(); };
function titleCase(text) {
  return text.toLowerCase().replace(/(^|[\s\-_(\["'“‘])([a-zà-þ])/g, function (_, p, c) { return p + c.toUpperCase(); });
}
function snakeCase(text) { return wordsOf(text).map(lower).join('_'); }
function camelCase(text) {
  return wordsOf(text).map(function (w, i) {
    const l = w.toLowerCase();
    return i === 0 ? l : l.charAt(0).toUpperCase() + l.slice(1);
  }).join('');
}

function formatJSON(text) { return JSON.stringify(JSON.parse(text), null, 2); }
function minifyJSON(text) { return JSON.stringify(JSON.parse(text)); }

function utf8Bytes(text) {
  const bytes = [];
  for (const ch of text) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) bytes.push(cp);
    else if (cp < 0x800) bytes.push(0xC0 | (cp >> 6), 0x80 | (cp & 63));
    else if (cp < 0x10000) bytes.push(0xE0 | (cp >> 12), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
    else bytes.push(0xF0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
  }
  return bytes;
}

function utf8Decode(bytes) {
  let out = '';
  for (let i = 0; i < bytes.length;) {
    const b = bytes[i];
    let cp, n;
    if (b < 0x80) { cp = b; n = 1; }
    else if (b >> 5 === 6) { cp = b & 31; n = 2; }
    else if (b >> 4 === 14) { cp = b & 15; n = 3; }
    else if (b >> 3 === 30) { cp = b & 7; n = 4; }
    else throw new Error('不是有效的 UTF-8');
    for (let k = 1; k < n; k++) {
      const c = bytes[i + k];
      if (c === undefined || c >> 6 !== 2) throw new Error('不是有效的 UTF-8');
      cp = (cp << 6) | (c & 63);
    }
    out += String.fromCodePoint(cp);
    i += n;
  }
  return out;
}

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function base64Encode(text) {
  const bytes = utf8Bytes(text);
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const n = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0);
    out += B64[(n >> 18) & 63] + B64[(n >> 12) & 63];
    out += i + 1 < bytes.length ? B64[(n >> 6) & 63] : '=';
    out += i + 2 < bytes.length ? B64[n & 63] : '=';
  }
  return out;
}

function base64Decode(text) {
  const clean = text.replace(/\s/g, '').replace(/-/g, '+').replace(/_/g, '/').replace(/=+$/, '');
  if (!/^[A-Za-z0-9+/]*$/.test(clean) || clean.length % 4 === 1) throw new Error('不是有效的 Base64');
  const bytes = [];
  for (let i = 0; i < clean.length; i += 4) {
    const chunk = clean.slice(i, i + 4);
    let n = 0;
    for (let k = 0; k < 4; k++) n = (n << 6) | (k < chunk.length ? B64.indexOf(chunk[k]) : 0);
    bytes.push((n >> 16) & 255);
    if (chunk.length > 2) bytes.push((n >> 8) & 255);
    if (chunk.length > 3) bytes.push(n & 255);
  }
  return utf8Decode(bytes);
}

function urlEncode(text) { return encodeURIComponent(text); }
function urlDecode(text) { return decodeURIComponent(text.replace(/\+/g, ' ')); }

module.exports = {
  fixLineBreaks: fixLineBreaks,
  countText: countText,
  upper: upper,
  lower: lower,
  titleCase: titleCase,
  snakeCase: snakeCase,
  camelCase: camelCase,
  formatJSON: formatJSON,
  minifyJSON: minifyJSON,
  base64Encode: base64Encode,
  base64Decode: base64Decode,
  urlEncode: urlEncode,
  urlDecode: urlDecode,
};
