import hljs from 'highlight.js';
import {q} from './util';

export default class EmbedMaker {
  constructor(params) {
    this.api = params.api;
    this.embeds = {};

    // TODO: Allow providers to be disabled
    this.disableAll = params.disableAll || false;
    this.disableInstagram = params.disableInstagram || false;
    this.disableTwitter = params.disableTwitter || false;
  }

  async render(urls, targetEl) {
    if (this.disableAll) return;

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
    this._loadScript('//platform.instagram.com/en_US/embeds.js');
  }

  renderPasteEl(embedEl) {
    hljs.highlightBlock(embedEl.querySelector('pre'));
    q(embedEl, '.le-meta', metaEl => {
      metaEl.addEventListener('click', () => metaEl.parentNode.classList.toggle('is-expanded'));
    });
  }

  renderTwitter(embedEl) {
    if (this.disableTwitter) return;
    if (window.twttr) window.twttr.widgets.load();
    this._loadScript('//platform.twitter.com/widgets.js');
  }

  _ensureEmbedEl(url) {
    let el = this.embeds[url].el;
    if (el) return el;
    el = document.createElement('div');
    el.className = 'message__embed';
    el.dataset.url = url;
    return (this.embeds[url].el = el);
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
    });
  }

  _loadScript(src) {
    const id = src.replace(/\W/g, '_');
    if (document.getElementById(id)) return;
    const el = document.createElement('script');
    [el.id, el.src] = [id, src];
    document.getElementsByTagName('head')[0].appendChild(el);
  }
}
