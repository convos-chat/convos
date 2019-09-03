// *foo*     or _foo_     = <em>foo</em>
// **foo**   or __foo__   = <strong>foo</strong>
// ***foo*** or ___foo___ = <em><strong>foo</strong></em>
// \*foo*    or \_foo_    = *foo* or _foo_

import emojione from 'emojione';

const codeToHtmlRe = new RegExp('(\\\\?)`([^`]+)`', 'g');
const linkRe = new RegExp('https?://\\S+', 'g');
const mdToHtmlRe = new RegExp('(^|\\s)(\\\\?)(\\*+|_+)(\\w[^<]*?)\\3', 'g');
const text2emojiMap = {};
let text2emojiRe;

export function md(str, params = {}) {
  if (params.escape !== false) str = xmlEscape(str);

  str = str.replace(mdToHtmlRe, (all, b, esc, md, text) => {
    if (md.match(/^_/) && text.match(/^[A-Z]+$/)) return all; // Avoid turning __DATA__ into <strong>DATA</strong>
    const len = md.length;
    if (len == 1) return esc ? all.replace(/^\\/, '') : b + '<em>' + text + '</em>';
    if (len == 2) return esc ? all.replace(/^\\/, '') : b + '<strong>' + text + '</strong>';
    if (len == 3) return esc ? all.replace(/^\\/, '') : b + '<em><strong>' + text + '</strong></em>';
    return all;
  });

  str = str.replace(codeToHtmlRe, (all, esc, text) => {
    return esc ? all.replace(/^\\/, '') : '<code>' + text + '</code>';
  });

  if (params.links !== false) {
    str = str.replace(linkRe, url => {
      const parts = url.match(/^(.*?)([.!?])?$/);
      return '<a href="' + parts[1] + '" target="_blank">' + parts[1].replace(/^https:\/\//, '') + '</a>' + (parts[2] || '');
    });
  }

  if (params.emoji !== false) {
    str = str.replace(text2emojiRe, (all, pre, emoji) => pre + (text2emojiMap[emoji] || emoji));
    str = emojione.toImage(str);
  }

  return str;
}

export function text2emoji(str, emoji) {
  text2emojiMap[str] = emoji;
  text2emojiRe = Object.keys(text2emojiMap).map(s => s.replace(/([()])/g, '\\$1')).join('|');
  text2emojiRe = new RegExp('(^|\\s)(' + text2emojiRe + ')(?=\\s|$)', 'i');
}

const xmlEscapeMap = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  "'": '&quot;',
  '"': '&quot;',
};

export function xmlEscape(str) {
  return str.replace(/[&<>"']/g, m => xmlEscapeMap[m]);
}

text2emoji('&lt;3', ':heart:');
text2emoji(':(', ':disappointed:');
text2emoji(':)', ':slight_smile:');
text2emoji(':/', ':confused:');
text2emoji(':D', ':smiley:');
text2emoji(':P', ':stuck_out_tongue:');
text2emoji(';)', ':wink:');
text2emoji(';D', ':wink:');
text2emoji('<3', ':heart:');
