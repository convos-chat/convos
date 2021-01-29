/**
 * A collection of markdown utitities.
 *
 * @module md
 * @exports emojiAliases
 * @exports emojis
 * @exports md
 */

import twemoji from 'twemoji';
import {route} from '../store/Route';
import {regexpEscape} from './util';

const emojiByGroup = {};
const emojiByName = {};
const linkRe = new RegExp('\\b[a-z]{2,5}://\\S+', 'g');

// Modifying this from the outside will break emojiRe below
export const emojiAliases = {
  ':confused:': ':/',
  ':disappointed:': ':(',
  ':grin:': ';D',
  ':heart:': '&lt;3',
  ':kissing:': ':-*',
  ':open_mouth:': ':O',
  ':slight_smile:': ':)',
  ':smiley:': ':D',
  ':stuck_out_tongue:': ':P',
  ':thumbsup:': '(Y)',
  ':wink:': ';)',
};

const emojiRe = new RegExp('(^|\\s)(:\\w+:|' + Object.keys(emojiAliases).map(k => regexpEscape(emojiAliases[k])).join('|') + ')(?=\\s|\\.|$)', 'gi'); // :short_code:, :(, :), :/, :D, :P, ;), ;D, <3

/**
 * emojis() is a function to return either a single emoji or a list of emojis
 * by group.
 *
 * @param {String} lookup Either an emoji name or an emoji group.
 * @param {String} type Can be "group" or "emoji"
 * @return {Array} Returns a list of emojis if type is "group"
 * @return {Object} Return s single emoji or empty object if no emoji was matched.
 */
export function emojis(lookup, type = 'single') {
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

  return type == 'group' ? (emojiByGroup[lookup] || []) : (emojiByName[lookup] || {});
}

/**
 * md() can convert a (subset) of markdown rules into a HTML string.
 *
 * @example
 * // Hey <em>foo</em> <strong>bar</strong> <em><strong>baz</strong></em> <em><strong>baz</strong></em>
 * md("Hey *foo* **bar** ***baz***!");
 *
 * // A <a href="https://convos.chat">link</a>
 * md("A [link](https://convos.chat)");
 *
 * // A link to <a href="https://convos.chat" target="_blank">convos.chat</a>
 * md('A link to https://convos.chat');
 *
 * // A link to <a href="mailto:jhthorsen@cpan.org" target="_blank">jhthorsen@cpan.org</a>
 * md('A link to mailto:jhthorsen@cpan.org');
 *
 * // Example <code>snippet</code>
 * md("Example `snippet`");
 *
 * // <img class="emoji" draggable="false" alt="🙂" src="..."> ...
 * md(':) :/ :( ;D &lt;3 :D :P ;) :heart:');
 *
 * @param {String} str A markdown formatter string.
 * @return {String} A string that might contain HTML tags.
 */
export function md(str) {
  const state = {};

  [
    xmlEscape,
    mdLink,
    mdUrl,
    mdCode,
    mdEmStrong,
    mdEmojis,
    mdBlockQuote,
  ].forEach(fn => { str = fn(str, state) });

  return str;
}

function mdBlockQuote(str) {
  return str.replace(/^&gt;\s(.*)/, (all, quote) => '<blockquote>' + quote + '</blockquote>');
}

function mdCode(str) {
  return str.replace(/(\\?)`(\S[^`]+)`/g, (all, esc, text) => {
    return esc ? all.replace(/^\\/, '') : '<code>' + text + '</code>';
  });
}

function mdEmojis(str) {
  return twemoji.parse(str.replace(emojiRe, (all, pre, emoji) => pre + (emojis(emoji).emoji || emoji)));
}

function mdEmStrong(str) {
  return str.replace(/(^|\s)(\\?)(\*+)(\w[^<]*?)\3/g, (all, b, esc, md, text) => {
    if (md.length == 1) return esc ? all.replace(/^\\/, '') : b + '<em>' + text + '</em>';
    if (md.length == 2) return esc ? all.replace(/^\\/, '') : b + '<strong>' + text + '</strong>';
    if (md.length == 3) return esc ? all.replace(/^\\/, '') : b + '<em><strong>' + text + '</strong></em>';
    return all;
  });
}

function mdLink(str, state = {}) {
  return str.replace(/\[([a-zA-Z][^\]]+)\]\(([^)]+)\)/g, (all, text, href) => {
    const scheme = href.match(/^\s*(\w+):/) || ['', ''];
    if (scheme[1] && ['http', 'https', 'mailto'].indexOf(scheme[1]) == -1) return all; // Avoid XSS links
    state.mdLinks = true;
    const first = href.substring(0, 1);
    const target = ['/', '#'].indexOf(first) != -1 ? '' : ' target="_blank"';
    return '<a href="' + route.urlFor(href) + '"' + target + '>' + text + '</a>';
  });
}

function mdUrl(str, state = {}) {
  if (state.mdLinks) return str;

  return str.replace(linkRe, url => {
    const parts = url.match(/^(.*?)(&\w+;|\W)?$/);
    return '<a href="' + parts[1] + '" target="_blank">' + parts[1] + '</a>' + (parts[2] || '');
  }).replace(/mailto:(\S+)/, (all, email) => {
    if (all.indexOf('">') != -1) return all;
    return '<a href="' + all + '" target="_blank">' + email + '</a>';
  });
}

function xmlEscape(str) {
  const map = {'&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&apos;', '"': '&quot;'};
  return str.replace(/[&<>"']/g, (m) => map[m]);
}
