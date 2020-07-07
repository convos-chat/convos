import hljs from './hljs';
import Reactive from './Reactive';
import {api} from './Api';
import {ensureChildNode, loadScript, q, removeChildNodes, showEl} from './util';
import {jsonhtmlify} from 'jsonhtmlify';
import {sameOrigin} from './util';

export default class EmbedMaker extends Reactive {
  constructor() {
    super();
    this.name = 'EmbedMaker';
    this.prop('persist', 'disableInstagram', false);
    this.prop('persist', 'disableTwitter', false);
    this.prop('persist', 'expandUrlToMedia', true);
    this.prop('ro', 'embeds', {});
  }

  render(messageEl, urls) {
    if (!this.expandUrlToMedia) return;

    const existingEls = {};
    q(messageEl, '.message__embed', el => { existingEls[el.dataset.url] = el });

    urls.forEach(url => {
      if (!this.embeds[url]) this._loadAndRender(url);
      if (!existingEls[url]) messageEl.appendChild(this._ensureEmbedEl(url));
      delete existingEls[url];
    });

    Object.keys(existingEls).forEach(url => {
      const el = existingEls[url];
      if (!el.classList.contains('has-message-details')) el.remove();
    });
  }

  renderInstagram(embedEl) {
    if (this.disableInstagram) return;
    if (window.instgrm) return window.instgrm.Embeds.process();
    loadScript('//platform.instagram.com/en_US/embeds.js');
  }

  renderPasteEl(embedEl) {
    hljs.lineNumbersBlock(embedEl.querySelector('pre'));
    q(embedEl, '.le-meta', metaEl => {
      metaEl.addEventListener('click', () => metaEl.parentNode.classList.toggle('is-expanded'));
    });
  }

  renderPhoto(embedEl) {
    q(embedEl, 'img', img => img.addEventListener('click', e => {
      e.preventDefault();
      this.showMediaBig(img);
    }));
  }

  renderTwitter(embedEl) {
    if (this.disableTwitter) return;
    if (window.twttr) window.twttr.widgets.load();
    loadScript('//platform.twitter.com/widgets.js');
  }

  showMediaBig(el) {
    const hide = () => {
      showEl(mediaWrapper, false);
      this.emit('hidemediawrapper', mediaWrapper);
    };

    const mediaWrapper = ensureChildNode(document.querySelector('body'), 'fullscreen-media-wrapper', mediaWrapper => {
      mediaWrapper.addEventListener('click', (e) => e.target == mediaWrapper && hide());
    });

    removeChildNodes(mediaWrapper);
    if (el === null) return hide();

    mediaWrapper.appendChild(el.cloneNode(true));
    showEl(mediaWrapper, true);
    return mediaWrapper;
  }

  toggleDetails(messageEl, message) {
    let detailsEl = messageEl.querySelector('.has-message-details');
    if (detailsEl) return showEl(detailsEl, 'toggle');

    const details = {...(message.sent || message)};
    [
      'bubbles', 'color', 'command', 'dispatchTo', 'embeds',
      'event', 'fromId', 'id', 'markdown', 'method', 'stopPropagation',
    ].forEach(k => delete details[k]);

    details.ts = message.ts.toLocaleString();
    detailsEl = jsonhtmlify(details.sent || details);
    detailsEl.className = ['message__embed', 'has-message-details', detailsEl.className].join(' ');
    messageEl.appendChild(detailsEl);
  }

  _bufAsBase64(buf) {
    const bin = new Uint8Array(buf).reduce((bin, byte) => bin + String.fromCharCode(byte), '');
    return window.btoa(bin);
  }

  _ensureEmbedEl(url) {
    return this.embeds[url].el || (this.embeds[url].el = ensureChildNode(null, 'message__embed', el => { el.dataset.url = url }));
  }

  _loadAndRender(url) {
    this.embeds[url] = {};
    return api('/api', 'embed', {url}).perform().then(op => {
      const embed = op.res.body;
      if (!embed.html) return;

      const embedEl = this._ensureEmbedEl(url);
      embedEl.innerHTML = embed.html;
      q(embedEl, 'a', aEl => { aEl.target = '_blank' });
      q(embedEl, 'img', img => this._processImage(img));

      const provider = (embed.provider_name || '').toLowerCase();
      if (provider == 'instagram') return this.renderInstagram(embedEl);
      if (provider == 'twitter') return this.renderTwitter(embedEl);

      const types = (embedEl.firstChild.className || '').split(/\s+/);
      if (types.indexOf('le-paste') != -1) return this.renderPasteEl(embedEl);

      q(embedEl, '.le-photo, .le-thumbnail', el => this.renderPhoto(embedEl));
    });
  }

  _processImage(img) {
    if (!sameOrigin(img.src)) return img.addEventListener('error', () => (img.style.display = 'none')); // TODO

    img.originalSource = img.src;
    img.src = '';
    img.style.visibility = 'hidden';
    fetch(img.originalSource).then(res => {
      const contentType = res.headers.get('Content-Type');
      return !contentType ? this._renderImage(img, new ArrayBuffer(0), {})
        : res.arrayBuffer().then(buf => this._renderImage(img, buf, {contentType}));
    });
  }

  _renderImage(img, buf, {contentType}) {
    const exifRotation = {1: 0, 3: 180, 6: 90, 8: 270};

    const dv = new DataView(buf);
    if (!contentType || buf.length < 2 || dv.getUint16(0) != 0xffd8) {
      img.src = img.originalSource;
      img.style.visibility = 'visible';
      return;
    }

    let maxBytes = dv.byteLength;
    let pos = 2;
    while (pos < maxBytes - 2 && !img.orientation) {
      const uint16 = dv.getUint16(pos);
      pos += 2;
      switch (uint16) {
        case 0xffe1: // Start of EXIF
          maxBytes = dv.getUint16(pos) + pos;
          pos += 2;
          break;
        case 0x0112: // Orientation tag
          img.orientation = exifRotation[dv.getUint16(pos + 6, false)];
          break;
      }
    }

    if (img.orientation !== undefined) img.style.transform = 'rotate(' + img.orientation + 'deg)';
    img.src = 'data:' + contentType + ';base64,' + this._bufAsBase64(buf);
    img.style.visibility = 'visible';
  }
}
