/**
 * A collection of markdown utitities.
 *
 * @module md
 * @exports emojiAliases
 * @exports emojis
 * @exports md
 * @exports xmlEscape
 */

import twemoji from 'twemoji';
import {regexpEscape} from './util';
import {urlFor} from '../store/router';

const codeToHtmlRe = new RegExp('(\\\\?)`([^`]+)`', 'g');
const emojiByGroup = {};
const emojiByName = {};
const linkRe = new RegExp('\\b[a-z]{2,5}://\\S+', 'g');
const mdLinkRe = new RegExp('\\[([^\\]]+)\\]\\(([^)]+)\\)', 'g');
const mdToHtmlRe = new RegExp('(^|\\s)(\\\\?)(\\*+|_+)(\\w[^<]*?)\\3', 'g');

// Modifying this from the outside will break emojiRe below
export const emojiAliases = {
  ':confused:': ':/',
  ':disappointed:': ':(',
  ':grin:': ';D',
  ':heart:': '&lt;3',
  ':slight_smile:': ':)',
  ':smiley:': ':D',
  ':stuck_out_tongue:': ':P',
  ':wink:': ';)',
};

const emojiRe = new RegExp('(^|\\s)(:\\w+:|' + Object.keys(emojiAliases).map(k => regexpEscape(emojiAliases[k])).join('|') + ')(?=\\W|$)', 'gi'); // :short_code:, :(, :), :/, :D, :P, ;), ;D, <3

const xmlEscapeMap = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  "'": '&apos;',
  '"': '&quot;',
};

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
 * // Hey <em>foo</em> <em>foo</em> <strong>bar</strong> <strong>bar</strong> <em><strong>baz</strong></em> <em><strong>baz</strong></em>
 * md("Hey *foo* _foo_ **bar** __baz__ ***baz***!");
 *
 * // A <a href="https://convos.by">link</a>
 * md("A [link](https://convos.by)");
 *
 * // A link to <a href="https://convos.by" target="_blank">convos.by</a>
 * md('A link to https://convos.by');
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
  str = str.replace(/[&<>"']/g, m => xmlEscapeMap[m]);

  let mdLinks = 0;
  str = str.replace(/^&gt;\s(.*)/, (all, quote) => {
    return '<blockquote>' + quote + '</blockquote>';
  }).replace(mdToHtmlRe, (all, b, esc, md, text) => {
    if (md.match(/^_/) && text.match(/^[A-Z]+$/)) return all; // Avoid turning __DATA__ into <strong>DATA</strong>
    if (md.length == 1) return esc ? all.replace(/^\\/, '') : b + '<em>' + text + '</em>';
    if (md.length == 2) return esc ? all.replace(/^\\/, '') : b + '<strong>' + text + '</strong>';
    if (md.length == 3) return esc ? all.replace(/^\\/, '') : b + '<em><strong>' + text + '</strong></em>';
    return all;
  }).replace(mdLinkRe, (all, text, href) => {
    mdLinks++;
    const target = href.indexOf('/') == 0 ? '_self' : '_blank';
    if (target == '_self') href = urlFor(href);
    return '<a href="' + href + '" target="' + target + '">' + text + '</a>';
  }).replace(codeToHtmlRe, (all, esc, text) => {
    return esc ? all.replace(/^\\/, '') : '<code>' + text + '</code>';
  });

  if (!mdLinks) {
    str = str.replace(linkRe, url => {
      const parts = url.match(/^(.*?)(&\w+;|\W)?$/);
      return '<a href="' + parts[1] + '" target="_blank">' + parts[1].replace(/^https:\/\//, '') + '</a>' + (parts[2] || '');
    }).replace(/mailto:(\S+)/, (all, email) => {
      if (all.indexOf('">') != -1) return all;
      return '<a href="' + all + '" target="_blank">' + email + '</a>';
    });
  }

  str = twemoji.parse(str.replace(emojiRe, (all, pre, emoji) => pre + (emojis(emoji).emoji || emoji)));

  return str;
}
