import escapeRegExp from 'lodash/escapeRegExp';
import twemoji from 'twemoji';
import {route} from '../store/Route';

export default class Emojis {
  constructor() {
    this.aliases = this._buildAliases();
    this.re = this._buildRe();
    this.byShortName = {};
    this.grouped = {};
    this.status = 'pending';
  }

  /**
   * Load in the emoji database.
   *
   * @return {Promise} The promise will be fulfilled when the databse is fetched and parsed.
   */
  async load() {
    if (['loading', 'success'].indexOf(this.status) !== -1) return this;
    this.status = 'loading';
    const res = await fetch(route.urlFor('/emojis/0bf11a9aff0d6da7b46f1490f86a71eb.json'));
    this._load((await res.json()).emojis);
    this.status = 'success';
    return this;
  }

  /**
   * Takes a string and replaces UTF8 emojis, emoji aliases and emoji
   * :shortname: with <img> tags. The input string will be returned
   * unaltered if no emojis was recognized.
   *
   * @param {String} str A string with emoji codes.
   * @return {String} A string with HTML markup.
   */
  markup(str) {
    return twemoji.parse(str.replace(this.re, (all, pre, match) => {
      const shortname = this.aliases[match] || match;
      const emoji = this.byShortName[shortname];
      return pre + (emoji && emoji.emoji || match);
    }));
  }

  /**
   * Takes a query string and tries to find emojis.
   *
   * @param {String} q A query string.
   * @return {Array} An array of emoji objects.
   */
  search(q) {
    q = q.toLowerCase();
    const group = this.grouped[q] || this.grouped[q.substring(0, 2)] || {};
    return Object.keys(group)
      .sort((a, b) => group[a] - group[b])
      .map(shortname => this.byShortName[shortname])
      .filter(emoji => (emoji.shortname + emoji.name).toLowerCase().indexOf(q) !== -1);
  }

  _buildAliases() {
    return {
      '&lt;3': ':heart:', // Because "<3" str is often escaped by I18N.md()
      '(Y)':   ':thumbsup:',
      ':(':    ':disappointed:',
      ':)':    ':slight_smile:',
      ':-*':   ':kissing:',
      ':/':    ':confused:',
      ':D':    ':smiley:',
      ':O':    ':open_mouth:',
      ':P':    ':stuck_out_tongue:',
      ';)':    ':wink:',
      ';D':    ':grin:',
    };
  }

  _buildRe() {
    // The regexp will match one of :short_code:, :(, :), :/, :D, :P, ;), ;D, <3, ...
    // followed by a space, comma, dot or end of string
    const re = Object.keys(this.aliases).sort().map(escapeRegExp).join('|');
    return new RegExp('(^|\\s)(:\\w+:|' + re + ')(?=\\s|\\,|\\.|$)', 'gi');
  }

  // This is used in unit tests
  _load(emojis) {
    this.grouped = {};
    for (const emoji of emojis) {
      if (!(emoji.emoji && emoji.shortname)) continue;

      // Normalizing input
      if (!emoji.name) emoji.name = emoji.shortname;
      delete emoji.category;
      delete emoji.html;
      delete emoji.order;
      delete emoji.unicode;

      this.byShortName[emoji.shortname] = emoji;
      this._toGrouped(emoji);
    }
  }

  _toGrouped(emoji) {
    const grouped = this.grouped;
    const groups = [emoji.shortname, emoji.name].join('-').replace(/\W+/, ' ').match(/\W(\w{2})/g);

    (groups || []).forEach((g, i) => {
      g = g.substring(1).toLowerCase();
      if (!grouped[g]) grouped[g] = {};
      grouped[g][emoji.shortname] = i;

      g = g[0];
      if (!grouped[g]) grouped[g] = {};
      grouped[g][emoji.shortname] = i;
    });
  }
}
