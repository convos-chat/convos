import hljs from '../js/hljs';
import Reactive from '../js/Reactive';
import Time from '../js/Time';
import {api} from '../js/Api';
import {i18n} from './I18N';
import {jsonhtmlify} from 'jsonhtmlify';
import {q, str2color} from '../js/util';

const EMBED_CACHE = {};
let ID = 0;

export default class Messages extends Reactive {
  constructor() {
    super();
    this.prop('ro', 'length', () => this.messages.length);
    this.prop('ro', 'messages', []);
    this.prop('rw', 'expandUrlToMedia', true);
    this.prop('rw', 'raw', false);
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
    [].push.apply(this.messages, this._fill(list));
    return this.update({messages: true});
  }

  render(msgIndex = -1) {
    if (msgIndex != -1) {
      const msg = this.get(msgIndex);
      if (msg && !msg.rendered) {
        msg.embeds = this._embeds(msg);
        msg.rendered = true;
        this.update({messages: true});
      }

      return this.messages;
    }

    let prev = {};
    const markdownMethod = this.raw ? 'lmdRaw' : 'lmd';
    return this.messages.map((msg, i) => {
      msg.index = i;
      if (msg.className) return (prev = msg); // already processed

      msg.dayChanged = this._dayChanged(msg, prev);
      msg.className = this._className(msg, prev);
      msg.embeds = [];
      msg.markdown = i18n[markdownMethod](msg.message, ...(msg.vars || []));

      return (prev = msg);
    });
  }

  toArray() {
    return this.messages;
  }

  update(params) {
    if (params.hasOwnProperty('expandUrlToMedia') && params.expandUrlToMedia != this.expandUrlToMedia) {
      this.messages.forEach(msg => delete msg.rendered);
    }
    if (params.hasOwnProperty('raw') && params.raw != this.raw) {
      this.messages.forEach(msg => delete msg.className);
    }

    return super.update(params);
  }

  unshift(list) {
    [].unshift.apply(this.messages, this._fill(list));
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
    return prev.ts && msg.ts.getDate() != prev.ts.getDate() ? true : false;
  }

  _embeds(msg) {
    const p = [];
    if (this._msgDetails(msg)) p.push(Promise.resolve({className: 'le-details', details: true, nodes: [jsonhtmlify(msg.details).lastChild]}));
    if (!this.expandUrlToMedia || msg.type == 'notice') return p;

    (msg.message.match(/https?:\/\/(\S+)/g) || []).forEach(url => {
      url = url.replace(/(\W)?$/, '');
      if (!this.embedCache[url]) this.embedCache[url] = this._loadEmbed(msg, url);
      p.push(this.embedCache[url]);
    });

    return p.map(p => p.catch(err => console.error('[Messages:embed]', msg, err)));
  }

  _fill(messages) {
    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i];
      if (!msg.from) [msg.internal, msg.from] = [true, 'Convos'];
      if (!msg.type) msg.type = 'notice';

      msg.color = msg.from == 'Convos' ? 'inherit' : str2color(msg.from.toLowerCase());
      msg.ts = new Time(msg.ts);
      msg.id = ++ID;
    }

    return messages;
  }

  async _loadEmbed(msg, url) {
    const op = await api('/api', 'embed', {url}).perform();
    const embed = op.res.body;

    embed.nodes = [];
    embed.provider = (embed.provider_name || '').toLowerCase();
    if (!embed.html) return embed;

    let embedEl = document.createRange().createContextualFragment(embed.html).firstChild;
    if (!embedEl) return embed;

    embedEl = this._renderVideoChat(msg, embed, embedEl) || this._renderPaste(msg, embed, embedEl) || embedEl;
    q(embedEl, 'img', ['error', (e) => (e.target.style.display = 'none')]);
    q(embedEl, '.le-goto-link', (el) => el.parentNode.children.length == 1 && el.parentNode.remove());

    delete embed.html;
    embed.className = embedEl.className;
    embed.nodes = embedEl.tagName.toLowerCase() == 'iframe' ? [embedEl] : [].slice.call(embedEl.childNodes, 0);

    return embed;
  }

  _msgDetails(msg) {
    if (msg.hasOwnProperty('details')) return msg.details;
    if (msg.type != 'error' && msg.type != 'notice') return (msg.details = null);

    const details = {...(msg.sent || msg)};

    [
      'bubbles',           'className',   'command',
      'connection_id',     'dispatchTo',  'color',      'dayChanged',
      'embeds',            'event',       'fresh',      'highlight',
      'id',                'index',       'internal',   'markdown',
      'method',            'rendered',    'silent',     'stopPropagation',
      'ts',
    ].forEach(k => delete details[k]);

    return Object.keys(details).sort().join(':') == 'from:message:type' ? (msg.details = null) : (msg.details = details);
  }

  _renderPaste(msg, embed, embedEl) {
    const pre = embedEl.querySelector('pre');
    return pre && [embedEl, hljs.lineNumbersBlock(pre)][0];
  }

  _renderVideoChat(msg, embed, embedEl) {
    const path = new URL(embed.url).pathname.replace(/\/+$/, '').split('/');
    const isVideoLink = path.length && (embedEl.classList.contains('le-video-chat') || path.includes('video'));
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
