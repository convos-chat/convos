import hljs from '../js/hljs';
import Reactive from '../js/Reactive';
import Time from '../js/Time';
import {convosApi} from '../js/Api';
import {createElement, q, str2color} from '../js/util';
import {i18n} from './I18N';
import {jsonhtmlify} from 'jsonhtmlify';

const EMBED_CACHE = {};
let ID = 10000;

export default class Messages extends Reactive {
  constructor() {
    super();
    this.prop('ro', 'length', () => this.messages.length);
    this.prop('ro', 'messages', []);
  }

  clear() {
    this.messages.length = 0;
    return this.update({messages: true});
  }

  get(i) {
    return i < 0 ? this.messages.slice(i)[0] : this.messages[i];
  }

  push(list) {
    [].push.apply(this.messages, this._fill(list));
    return this.update({messages: true});
  }

  render({expand, raw}) {
    let prev = {};

    for (const msg of this.messages) {
      if (typeof msg.className === 'undefined') {
        msg.details = this._msgDetails(msg); // Must be called before other methods "pollute" msg
        msg.dayChanged = this._dayChanged(msg, prev);
        msg.className = this._className(msg, prev);
        msg.embeds = [];
        prev = msg;
      }
      if (raw !== msg.raw) {
        let str = msg.vars ? i18n.l(msg.message, ...msg.vars) : msg.message;
        msg.html = raw ? i18n.raw(str) : i18n.md(str);
        msg.raw = raw;
      }
      if (expand && msg.seen && !msg.expand && msg.type !== 'notice') {
        msg.embeds = this._expandUrlToMedia(msg);
        msg.expand = expand;
      }
    }

    return this.messages;
  }

  toArray() {
    return this.messages;
  }

  unshift(list) {
    [].unshift.apply(this.messages, this._fill(list));
    return this.update({messages: true});
  }

  update(params) {
    if (Object.hasOwn(params, 'seen') && this.messages[params.seen]) {
      this.messages[params.seen].seen = true;
    }

    return super.update(params);
  }

  _changed(params, paramName) {
    return Object.hasOwn(params, paramName) && params[paramName] !== this[paramName];
  }

  _className(msg, prev) {
    const classes = ['message'];
    if (msg.type) classes.push('is-type-' + msg.type);
    if (msg.highlight) classes.push('is-highlighted');
    const sameFrom = msg.from === prev.from && msg.conversation_id === prev.conversation_id && msg.connection_id === prev.connection_id;
    classes.push(!msg.dayChanged && sameFrom ? 'has-same-from' : 'has-not-same-from');
    return classes.join(' ');
  }

  _dayChanged(msg, prev) {
    return prev.ts && msg.ts.getDate() !== prev.ts.getDate() ? true : false;
  }

  _expandUrlToMedia(msg) {
    return (msg.message.match(/https?:\/\/(\S+)/g) || []).map(url => {
      url = url.replace(/(\W)?$/, '');
      if (!EMBED_CACHE[url]) EMBED_CACHE[url] = this._loadEmbed(msg, url);
      return EMBED_CACHE[url].finally(() => this.update({messages: true}));;
    });
  }

  _fill(messages) {
    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i];
      if (!msg.from) [msg.internal, msg.from] = [true, 'Convos'];
      if (!msg.type) msg.type = 'notice';

      msg.color = msg.from === 'Convos' ? 'inherit' : str2color(msg.from.toLowerCase());
      msg.ts = new Time(msg.ts);
      msg.id = 'M' + String(++ID);
    }

    return messages;
  }

  _isProbablyConvosVideoLink(url) {
    return !!url.match(/\/video\/[^/]+\/[^/]+($|\?)/);
  }

  async _loadEmbed(msg, url) {
    const op = await convosApi.op('embed', {url}).perform();
    const embed = op.res.body;

    embed.nodes = [];
    embed.provider = (embed.provider_name || '').toLowerCase();
    if (!embed.html) return embed;

    let embedEl = document.createRange().createContextualFragment(embed.html).firstChild;
    if (!embedEl) return embed;

    embedEl = this._renderVideoChat(msg, embed, embedEl) || this._renderPaste(msg, embed, embedEl) || embedEl;
    q(embedEl, 'img', ['error', (e) => (e.target.style.display = 'none')]);
    q(embedEl, '.le-goto-link', (el) => el.parentNode.children.length === 1 && el.parentNode.remove());

    delete embed.html;
    embed.className = embedEl.className;
    embed.nodes = embedEl.tagName.toLowerCase() === 'iframe' ? [embedEl] : [].slice.call(embedEl.childNodes, 0);

    return embed;
  }

  _msgDetails(msg) {
    if (msg.type !== 'error' && msg.type !== 'notice') return null;
    const details = {...(msg.sent || msg)};

    [
      'bubbles',          'command',   'connection_id',  'dispatchTo',
      'color',            'seen',      'event',          'fresh',
      'id',               'internal',  'method',         'silent',
      'stopPropagation',  'ts',                          
    ].forEach(k => delete details[k]);

    return jsonhtmlify(details).lastChild?.innerHTML;
  }

  _renderPaste(msg, _embed, embedEl) {
    const pre = embedEl.querySelector('pre');
    if (!pre) return;

    const meta = embedEl.querySelector('.le-meta');
    if (meta) meta.appendChild(createElement('a', {className: 'prevent-default', href: '#action:expand:' + msg.id, innerHTML: '<i class="fas fa-angle-down"/>'}));
    hljs.lineNumbersBlock(pre);
    return embedEl;
  }

  _renderVideoChat(msg, embed, embedEl) {
    const path = new URL(embed.url).pathname.replace(/\/+$/, '').split('/');
    const isVideoLink = path.length && (embedEl.classList.contains('le-video-chat') || this._isProbablyConvosVideoLink(embed.url));
    if (!isVideoLink) return;

    // Turn "Some-Cool-convosTest" into "Some Cool Convos Test"
    const roomName = decodeURIComponent(path.slice(-1)[0]);
    const humanName = roomName.replace(/\s-\s[\w-]+$/, '')
      .replace(/[_.-]+/g, ' ')
      .replace(/([a-z ])([A-Z])/g, (all, a, b) => a + ' ' + b.toUpperCase())
      .replace(/((?:^|[ ])\w)/g, (all) => all.toUpperCase());

    const message = i18n.l('Do you want to join the %1 video chat with "%2"?', embed.provider_name, humanName);

    embedEl = document.createElement('div');
    embedEl.className = 'le-card le-rich le-join-request le-provider-' + embed.provider;
    embedEl.innerHTML
      = '<a class="le-thumbnail" href="' + embed.url + '" target="convos_video"><i class="fas fa-video"></i></a>'
      + '<h3>' + message + '</h3>'
      + '<p class="le-description"><a href="' + embed.url + '" target="convos_video">' + i18n.l('Yes, I want to join.') + '</a></p>';

    if (msg.fresh) this.emit('notify', {...msg, message});

    return embedEl;
  }
}
