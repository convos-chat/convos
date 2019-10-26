import hljs from './hljs';
import Reactive from './Reactive';
import {ensureChildNode, loadScript, q, removeChildNodes, showEl} from './util';

export default class EmbedMaker extends Reactive {
  constructor(params) {
    super();
    this.name = 'EmbedMaker';
    this._localStorageAttr('disableInstagram', false);
    this._localStorageAttr('disableTwitter', false);
    this._localStorageAttr('expandUrlToMedia', true);
    this._readOnlyAttr('api', params.api);
    this._readOnlyAttr('embeds', {});
  }

  async render(urls, targetEl) {
    if (!this.expandUrlToMedia) return;

    const existingEls = {};
    q(targetEl, '.message__embed', el => { existingEls[el.dataset.url] = el });

    urls.forEach(url => {
      if (!this.embeds[url]) this._loadAndRender(url);
      if (!existingEls[url]) targetEl.appendChild(this._ensureEmbedEl(url));
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
    q(embedEl, 'img', img => img.addEventListener('click', () => this.showMedia(img)));
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

  _ensureEmbedEl(url) {
    return this.embeds[url].el || (this.embeds[url].el = ensureChildNode(null, 'message__embed', el => { el.dataset.url = url }));
  }

  _loadAndRender(url) {
    this.embeds[url] = {};
    return this.api.operation('embed', {url}).perform().then(op => {
      const embedEl = this._ensureEmbedEl(url);
      const embed = op.res.body;
      embedEl.innerHTML = embed.html;
      q(embedEl, 'a', aEl => { aEl.target = '_blank' });

      const provider = (embed.provider_name || '').toLowerCase();
      if (provider == 'instagram') return this.renderInstagram(embedEl);
      if (provider == 'twitter') return this.renderTwitter(embedEl);

      const types = (embedEl.firstChild.className || '').split(/\s+/);
      if (types.indexOf('le-paste') != -1) return this.renderPasteEl(embedEl);

      q(embedEl, '.le-photo, .le-thumbnail', el => this.renderPhoto(embedEl));
    });
  }
}
