// *foo*     or _foo_     = <em>foo</em>
// **foo**   or __foo__   = <strong>foo</strong>
// ***foo*** or ___foo___ = <em><strong>foo</strong></em>
// \*foo*    or \_foo_    = *foo* or _foo_

import twemoji from 'twemoji';

const codeToHtmlRe = new RegExp('(\\\\?)`([^`]+)`', 'g');
const emojiByGroup = {};
const emojiByName = {};
const linkRe = new RegExp('https?://\\S+', 'g');
const mdLinkRe = new RegExp('\\[([^]+)\\]\\(([^)]+)\\)');
const mdToHtmlRe = new RegExp('(^|\\s)(\\\\?)(\\*+|_+)(\\w[^<]*?)\\3', 'g');

const emojiAliases = {
  ':confused:': ':/',
  ':disappointed:': ':(',
  ':grin:': ';D',
  ':heart:': '&lt;3',
  ':slight_smile:': ':)',
  ':smiley:': ':D',
  ':stuck_out_tongue:': ':P',
  ':wink:': ';)',
};

const emojiRe = new RegExp('(^|\\s)(:\\w+:|:[()/DP]|;[)D]|&lt;3)(?=\\W|$)', 'gi'); // :short_code:, :(, :), :/, :D, :P, ;), ;D, <3

const xmlEscapeMap = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  "'": '&apos;',
  '"': '&quot;',
};

export function emojis(lookup, type = 'emoji') {
  if (window.__emojiList) {
    window.__emojiList.forEach(entry => {
      if ((entry.shortname || '')[0] != ':') return;

      if (emojiAliases[entry.shortname]) emojiByName[emojiAliases[entry.shortname]] = entry;
      emojiByName[entry.shortname] = entry;

      if (entry.category) {
        const category = ':' + entry.category;
        if (!emojiByGroup[category]) emojiByGroup[category] = [];
        emojiByGroup[category].push(entry);
      }

      entry.shortname.match(/(_|:)\w/g).forEach(k => {
        if (!emojiByGroup[k]) emojiByGroup[k] = [];
        emojiByGroup[k].push(entry);
      });

      // Use a bit less memory. (Not sure if it matters)
      delete entry.category;
      delete entry.html;
      delete entry.order;
      delete entry.unicode;
    });

    delete window.__emojiList;
  }

  return type == 'group' ? (emojiByGroup[lookup] || []) : (emojiByName[lookup] || {})[type];
}

export function md(str, params = {}) {
  if (params.escape !== false) str = xmlEscape(str);

  str = str.replace(/^&gt;\s(.*)/, (all, quote) => {
    return '<blockquote>' + quote + '</blockquote>';
  }).replace(mdToHtmlRe, (all, b, esc, md, text) => {
    if (md.match(/^_/) && text.match(/^[A-Z]+$/)) return all; // Avoid turning __DATA__ into <strong>DATA</strong>
    if (md.length == 1) return esc ? all.replace(/^\\/, '') : b + '<em>' + text + '</em>';
    if (md.length == 2) return esc ? all.replace(/^\\/, '') : b + '<strong>' + text + '</strong>';
    if (md.length == 3) return esc ? all.replace(/^\\/, '') : b + '<em><strong>' + text + '</strong></em>';
    return all;
  }).replace(mdLinkRe, (all, text, href) => {
    return '<a href="' + href + '">' + text + '</a>';
  });

  str = str.replace(codeToHtmlRe, (all, esc, text) => {
    return esc ? all.replace(/^\\/, '') : '<code>' + text + '</code>';
  });

  if (params.links !== false) {
    str = str.replace(linkRe, url => {
      const parts = url.match(/^(.*?)([.!?])?$/);
      return '<a href="' + parts[1] + '" target="_blank">' + parts[1].replace(/^https:\/\//, '') + '</a>' + (parts[2] || '');
    }).replace(/mailto:(\S+)/, (all, email) => {
      return '<a href="' + all + '" target="_blank">' + email + '</a>';
    });
  }

  if (params.emoji !== false) {
    str = twemoji.parse(str.replace(emojiRe, (all, pre, emoji) => pre + (emojis(emoji) || emoji)));
  }

  return str;
}

export function xmlEscape(str) {
  return str.replace(/[&<>"']/g, m => xmlEscapeMap[m]);
}
