import Reactive from '../js/Reactive';
import {api} from '../js/Api';
import {ensureChildNode, q, removeChildNodes, replaceClassName} from '../js/util';
import {l} from '../js/i18n';

export default class Viewport extends Reactive {
  constructor() {
    super();
    this.prop('cookie', 'colorScheme', 'auto');
    this.prop('cookie', 'theme', 'convos');
    this.prop('cookie', 'compactDisplay', false);
    this.prop('persist', 'expandUrlToMedia', true);
    this.prop('persist', 'version', '');
    this.prop('ro', '_settings', () => ({})); // Hack to trigger updates when settings() is called
    this.prop('ro', 'colorSchemeOptions', ['Auto', 'Light', 'Dark'].map(o => [o.toLowerCase(), o]));
    this.prop('ro', 'isWide', () => this.width > 800);
    this.prop('ro', 'l', () => l);
    this.prop('ro', 'themeOptions', () => Array.from(this._themeMap.entries()));
    this.prop('rw', 'height', 0);
    this.prop('rw', 'osColorScheme', '');
    this.prop('rw', 'width', 0);

    this._themeMap = new Map([]);
  }

  async activateLanguage(val) {
    if (!val) val = this.settings('lang');
    const op = await api('/api', 'getDictionary', {lang: val}).perform();
    l.lang(val, op.res.body.dictionary);
    return this.settings('lang', val);
  }

  activateTheme(theme, colorScheme) {
    if (!this._themeMap.size) this.loadThemes();
    if (!theme) theme = this.theme;
    if (!colorScheme) colorScheme = this.colorScheme;

    const schemes = [colorScheme == 'auto' ? this.osColorScheme : colorScheme, 'normal', 'light'];
    let selectedEl;
    for (let i = 0; i < schemes.length; i++) {
      selectedEl = document.getElementById('theme_alt__' + schemes[i] + '-' + theme);
      if (selectedEl) break;
    }

    q(document, 'link[rel*="style"][title]', el => {
      if (!selectedEl) selectedEl = el; // Fallback
      el.disabled = true; // Not sure why, but this seems to bee required by firefox
      el.disabled = el.href == selectedEl.href ? false : true;
      el.setAttribute('media', el == selectedEl ? '' : 'none');
      el.setAttribute('rel', el == selectedEl ? 'stylesheet' : 'alternate stylesheet');
    });

    return this.update({colorScheme, theme});
  }

  hasColorSchemes(theme) {
    return q(document, 'link[id$="-' + theme + '"]').length > 1;
  }

  loadThemes() {
    q(document, 'link[rel="alternate stylesheet"][title]', el => {
      const name = el.title.replace(/\s\([a-z]+\)$/, '');
      this._themeMap.set(el.id.replace(/^theme_alt__[a-z]+-/, ''), name);
    });

    if (!this._matchMedia) {
      this._matchMedia = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : {addListener: () => {}};
      this._matchMedia.addListener(e => this.update({osColorScheme: e.matches ? 'dark' : 'light'}).activateTheme());
      this.update({osColorScheme: this._matchMedia.matches ? 'dark' : 'light'});
    }
  }

  settings(key, value) {
    return arguments.length == 2 ? [this._settingsSet(key, value), this][1].update({_settings: true}) : this._settingsGet(key);
  }

  showFullscreen(contentEl) {
    const mediaWrapper = ensureChildNode(document.body, 'fullscreen-wrapper', (el) => {
      el.addEventListener('click', (e) => e.target == el && el.hide());
      el.hide = () => {
        mediaWrapper.classList.add('hidden');
        this.emit('hidemediawrapper', mediaWrapper);
      };
    });

    removeChildNodes(mediaWrapper);
    if (!contentEl) return mediaWrapper.hide();

    mediaWrapper.classList.remove('hidden');
    mediaWrapper.appendChild(contentEl.cloneNode(true));
    return mediaWrapper;
  }

  _settingsGet(key) {
    if (key == 'app_mode') return document.body.classList.contains('for-app');
    if (key == 'lang') return document.documentElement.getAttribute('lang');
    if (key == 'notify_enabled') return document.body.classList.contains('notify-enabled');
    if (key == 'organization_name') key = 'contactorganization';
    if (key == 'organization_url') key = 'contactnetworkaddress';

    const el = this._settingsEl(key);
    if (!el) throw 'Cannot get settings for "' + key + '".';

    const bool = {no: false, yes: true};
    return key == 'contact' ? atob(el.content || '') : bool.hasOwnProperty(el.content) ? bool[el.content] : el.content;
  }

  _settingsEl(key) {
    return document.querySelector('meta[name="convos:' + key + '"]')
      || document.querySelector('meta[name="' + key + '"]');
  }

  _settingsSet(key, value) {
    if (key == 'app_mode') return replaceClassName('body', /(for-)(app|cms)/, value ? 'app' : 'cms');
    if (key == 'lang') return document.documentElement.setAttribute('lang', value);
    if (key == 'notify_enabled') return replaceClassName('body', /(notify-)(disabled)/, value ? 'enabled' : 'disabled');
    if (key == 'organization_name') key = 'contactorganization';
    if (key == 'organization_url') key = 'contactnetworkaddress';

    const el = this._settingsEl(key);
    if (!el) return;
    if (key == 'contact') value = btoa(value);
    if (typeof value == 'boolean') value = value ? 'yes' : 'no';
    el.content = value;
  }

  update(params) {
    document.body.classList[this.compactDisplay ? 'add' : 'remove']('is-compact');
    return super.update(params);
  }
}

export const viewport = new Viewport();
export const settings = (...params) => viewport.settings(...params);
