import hljs from '../js/hljs';
import Reactive from '../js/Reactive';
import Time from '../js/Time';
import {api} from '../js/Api';
import {i18n} from './I18N';
import {jsonhtmlify} from 'jsonhtmlify';
import {md} from '../js/md';
import {q, str2color} from '../js/util';

const EMBED_CACHE = {};

const INTERNAL_MESSAGE_KEYS = [
  'canToggleDetails',  'bubbles',     'className',  'command',
  'connection_id',     'dispatchTo',  'color',      'dayChanged',
  'embeds',            'event',
  'highlight',         'id',          'index',      'markdown',
  'method',            'rendered',    'silent',     'stopPropagation',
  'ts',
];

export default class Messages extends Reactive {
  constructor(params) {
    super();
    this.prop('ro', 'length', () => this.messages.length);
    this.prop('ro', 'messages', []);
    this.prop('rw', 'expandUrlToMedia', true);
    this.embedCache = EMBED_CACHE;
  }

  clear() {
    this.messages.length = 0;
    return this.update({messages: true});
  }

  get(i) {
    return i < 0 ? this.messages.slice(i)[0] : this.messages[i];
  }

  push(list) {
    [].push.apply(this.messages, list);
    return this.update({messages: true});
  }

  render(msgIndex = -1) {
    if (msgIndex != -1) {
      const msg = this.get(msgIndex);
      if (!msg.rendered) {
        msg.embeds = this._embeds(msg);
        this.update({messages: true});
        msg.rendered = true;
      }

      return this.messages;
    }

    let prev = {};
    return this.messages.map((msg, i) => {
      msg.index = i;
      if (msg.className) return (prev = msg); // already processed

      msg.dayChanged = this._dayChanged(msg, prev);
      msg.className = this._className(msg, prev);
      msg.embeds = [];
      msg.markdown = msg.vars ? i18n.md(msg.message, ...msg.vars) : md(msg.message);
      msg.rendered = false;

      return (prev = msg);
    });
  }

  toArray() {
    return this.messages;
  }

  unshift(list) {
    [].unshift.apply(this.messages, list);
    return this.update({messages: true});
  }

  _className(msg, prev) {
    const classes = ['message'];
    if (msg.type) classes.push('is-type-' + msg.type);
    if (msg.highlight) classes.push('is-highlighted');
    classes.push(!msg.dayChanged && msg.from == prev.from ? 'has-same-from' : 'has-not-same-from');
    return classes.join(' ');
  }

  _dayChanged(msg, prev) {
    return prev.ts && msg.ts.getDate() != prev.ts.getDate();
  }

  _embeds(msg) {
    const p = [];
    if (msg.canToggleDetails) p.push(this._renderDetails(msg));
    if (!this.expandUrlToMedia || msg.type == 'notice') return p;

    (msg.message.match(/https?:\/\/(\S+)/g) || []).forEach(url => {
      url = url.replace(/(\W)?$/, '');
      if (!this.embedCache[url]) this.embedCache[url] = this._loadEmbed(msg, url);
      p.push(this.embedCache[url]);
    });

    return p.map(p => p.catch(err => console.error('[Messages:embed]', msg, err)));
  }

  async _loadEmbed(msg, url) {
    const op = await api('/api', 'embed', {url}).perform();
    const embed = op.res.body;

    embed.nodes = [];
    if (!embed.html) return embed;
    const provider = embed.provider_name && embed.provider_name.toLowerCase() || '';
    embed.className = provider ? 'for-' + provider : embed.html ? 'for-unknown' : 'hidden';

    const embedEl = document.createRange().createContextualFragment(embed.html).firstChild;
    if (!embedEl) return embed;

    const types = (embedEl && embedEl.className || '').split(/\s+/);
    embed.nodes = [].slice.call(embedEl.childNodes, 0);
    if (types.indexOf('le-paste') != -1) this._renderPaste(embed, embedEl);
    if (provider == 'jitsi') this._renderJitsi(embed, embedEl);

    q(embedEl, 'img', ['error', (e) => (e.target.style.display = 'none')]);
    q(embedEl, '.le-goto-link', (el) => el.parentNode.children.length == 1 && el.parentNode.remove());

    embed.className = [embed.className, embedEl.className].join(' ');
    delete embed.html;
    return embed;
  }

  async _renderDetails(msg) {
    const details = {...(msg.sent || msg)};
    INTERNAL_MESSAGE_KEYS.forEach(k => delete details[k]);
    return {className: 'for-details', details: true, nodes: [jsonhtmlify(details).lastChild]};
  }

  _renderPaste(embed, embedEl) {
    const pre = embedEl.querySelector('pre');
    if (!pre) return;
    hljs.lineNumbersBlock(pre);
  }

  _renderJitsi(embed, embedEl) {
    const url = new URL(embed.url);
    const roomName = decodeURIComponent(url.pathname.replace(/^\//, ''));
    if (!roomName || roomName.indexOf('/') != -1) return;

    // Turn "Some-Cool-convosTest" into "Some Cool Convos Test"
    let humanName = roomName.replace(/^irc-[^-]+-/, '')
      .replace(/[_-]+/g, ' ')
      .replace(/([a-z ])([A-Z])/g, (all, a, b) => a + ' ' + b.toUpperCase())
      .replace(/([ ]\w)/g, (all) => all.toUpperCase());

    embedEl = document.createElement('div');
    embedEl.className = 'le-card le-rich le-join-request';
    embedEl.innerHTML
      = '<a class="le-thumbnail" href="' + embed.url + '" target="' + roomName + '"><i class="fas fa-video"></i></a>'
      + '<h3>' + i18n.l('Do you want to join the %1 video chat with "%2"?', 'Jitsi', humanName) + '</h3>'
      + '<p class="le-description"><a href="' + embed.url + '" target="' + roomName + '">' + i18n.l('Yes, I want to join.') + '</a></p>';

    embed.nodes = [embedEl];
  }
}
