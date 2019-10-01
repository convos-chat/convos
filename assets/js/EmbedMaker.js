import hljs from 'highlight.js';
import {q} from './util';

export default class EmbedMaker {
  constructor(params) {
    // TODO: Allow providers to be disabled
    this.disableAll = params.disableAll || false;
    this.disableInstagram = params.disableInstagram || false;
    this.disableTwitter = params.disableTwitter || false;
  }

  renderEl(params) {
    if (this.disableAll) return null;
    if (!params.html.match(/<a.*href/)) params.html = `<a href="${params.url}">${params.html}</a>`;

    const embedEl = document.createElement('div');
    embedEl.className = 'message__embed';
    embedEl.innerHTML = params.html;
    q(embedEl, 'a', aEl => { aEl.target = '_blank' });

    const types = (embedEl.firstChild.className || '').split(/\s+/);
    if (types.indexOf('le-paste') != -1) this.renderPasteEl(embedEl, params);
    if (params.provider == 'instagram') this.renderInstagram(embedEl, params);
    if (params.provider == 'twitter') this.renderTwitter(embedEl, params);

    return embedEl;
  }

  renderInstagram(embedEl, params) {
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

  renderTwitter(embedEl, params) {
    if (this.disableTwitter) return;
    if (window.twttr) window.twttr.widgets.load();
    this._loadScript('//platform.twitter.com/widgets.js');
  }

  _loadScript(src) {
    const id = src.replace(/\W/g, '_');
    if (document.getElementById(id)) return;
    const el = document.createElement('script');
    [el.id, el.src] = [id, src];
    document.getElementsByTagName('head')[0].appendChild(el);
  }
}
