import Reactive from '../js/Reactive';
import {q} from '../js/util';

export default class Viewport extends Reactive {
  constructor() {
    super();
    this.prop('cookie', 'colorScheme', 'auto');
    this.prop('cookie', 'theme', 'convos');
    this.prop('ro', 'colorSchemeOptions', ['Auto', 'Light', 'Dark'].map(o => [o.toLowerCase(), o]));
    this.prop('ro', 'isWide', () => this.width > 800);
    this.prop('ro', 'themeOptions', () => Array.from(this._themeMap.entries()));
    this.prop('rw', 'height', 0);
    this.prop('rw', 'osColorScheme', '');
    this.prop('rw', 'width', 0);

    this._themeMap = new Map([]);
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
}

export const viewport = new Viewport();
