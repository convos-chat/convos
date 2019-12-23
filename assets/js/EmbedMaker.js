import hljs from './hljs';
import Reactive from './Reactive';
import {ensureChildNode, loadScript, q, removeChildNodes, showEl} from './util';
import {jsonhtmlify} from 'jsonhtmlify';

export default class EmbedMaker extends Reactive {
  constructor(params) {
    super();
    this.name = 'EmbedMaker';
    this.prop('persist', 'disableInstagram', false);
    this.prop('persist', 'disableTwitter', false);
    this.prop('persist', 'expandUrlToMedia', true);
    this.prop('ro', 'api', params.api);
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

    Object.keys(existingEls).forEach(url => existingEls[url].remove());
  }

  renderInstagram(embedEl) {
    if (this.disableInstagram) return;
    if (window.instgrm) return window.instgrm.Embeds.process();
    loadScript('//platform.instagram.com/en_US/embeds.js');
  }

  renderPasteEl(embedEl) {
    hljs.highlightBlock(embedEl.querySelector('pre'));
    q(embedEl, '.le-meta', metaEl => {
      metaEl.addEventListener('click', () => metaEl.parentNode.classList.toggle('is-expanded'));
    });
  }

  renderPhoto(embedEl) {
    q(embedEl, 'img', img => img.addEventListener('click', e => {
      e.preventDefault();
      this.showMedia(img);
    }));
  }

  renderTwitter(embedEl) {
    if (this.disableTwitter) return;
    if (window.twttr) window.twttr.widgets.load();
    loadScript('//platform.twitter.com/widgets.js');
  }

  showMedia(el) {
    const mediaWrapper = ensureChildNode(document.querySelector('body'), 'fullscreen-media-wrapper', mediaWrapper => {
      mediaWrapper.addEventListener('click', e => showEl(mediaWrapper, e.target != mediaWrapper));
    });

    removeChildNodes(mediaWrapper);
    mediaWrapper.appendChild(el.cloneNode());
    showEl(mediaWrapper, true);
  }

  toggleDetails(messageEl, message) {
    let detailsEl = messageEl.querySelector('.has-message-details');
    if (detailsEl) return showEl(detailsEl, 'toggle');

    const details = {...(message.sent || message)};
    [
      'bubbles', 'color', 'command', 'dayChanged', 'dispatchTo', 'embeds',
      'event', 'fromId', 'id', 'isSameSender', 'markdown', 'method', 'stopPropagation',
    ].forEach(k => delete details[k]);

    details.ts = message.ts.toLocaleString();
    detailsEl = jsonhtmlify(details.sent || details);
    detailsEl.className = ['message__embed', 'has-message-details', detailsEl.className].join(' ');
    messageEl.appendChild(detailsEl);
  }

  _ensureEmbedEl(url) {
    return this.embeds[url].el || (this.embeds[url].el = ensureChildNode(null, 'message__embed', el => { el.dataset.url = url }));
  }

  _loadAndRender(url) {
    this.embeds[url] = {};
    return this.api.operation('embed', {url}).perform().then(op => {
      const embed = op.res.body;
      if (!embed.html) return;

      const embedEl = this._ensureEmbedEl(url);
      embedEl.innerHTML = embed.html;
      q(embedEl, 'a', aEl => { aEl.target = '_blank' });
      q(embedEl, 'img', img => img.addEventListener('error', () => (embedEl.style.display = 'none')));

      const provider = (embed.provider_name || '').toLowerCase();
      if (provider == 'instagram') return this.renderInstagram(embedEl);
      if (provider == 'twitter') return this.renderTwitter(embedEl);

      const types = (embedEl.firstChild.className || '').split(/\s+/);
      if (types.indexOf('le-paste') != -1) return this.renderPasteEl(embedEl);

      q(embedEl, '.le-photo, .le-thumbnail', el => this.renderPhoto(embedEl));
    });
  }
}
