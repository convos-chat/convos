import Reactive from '../js/Reactive';
import {q} from '../js/util';

export default class ThemeManager extends Reactive {
  constructor() {
    super();
    this.prop('cookie', 'activeTheme', 'convos', {key: 'theme'});
    this.prop('cookie', 'colorScheme', 'auto');
    this.prop('cookie', 'compactDisplay', false);
    this.prop('ro', 'colorSchemeOptions', ['Auto', 'Light', 'Dark'].map(o => [o.toLowerCase(), o]));
    this.prop('ro', 'themeOptions', () => Array.from(this._stylesheets.entries()));
    this.prop('rw', 'osColorScheme', '');

    this._stylesheets = new Map([]);
  }

  hasColorScheme(name) {
    return q(document, 'link[id$="-' + name + '"]').length > 1;
  }

  start() {
    q(document, 'link[rel="alternate stylesheet"][title]', el => {
      const name = el.title.replace(/\s\([a-z]+\)$/, '');
      this._stylesheets.set(el.id.replace(/^theme_alt__[a-z]+-/, ''), name);
    });

    let osColorScheme = this.osColorScheme;
    if (!this._matchMedia) {
      this._matchMedia = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : {addListener: () => {}};
      this._matchMedia.addListener(e => this.update({osColorScheme: e.matches ? 'dark' : 'light'}));
      osColorScheme = this._matchMedia.matches ? 'dark' : 'light';
    }

    return this.update({compactDisplay: this.compactDisplay, osColorScheme});
  }

  update(params) {
    if (params.activeTheme || params.colorScheme || params.osColorScheme) this._activateTheme(params);
    return super.update(params);
  }

  _activateTheme(params) {
    const activeTheme = params.activeTheme || this.activeTheme;
    const colorScheme = params.colorScheme || this.colorScheme;
    const osColorScheme = params.osColorScheme || this.osColorScheme;
    const schemes = [(colorScheme == 'auto' ? osColorScheme : colorScheme), 'normal', 'light'];

    let selectedEl;
    for (let i = 0; i < schemes.length; i++) {
      selectedEl = document.getElementById('theme_alt__' + schemes[i] + '-' + activeTheme);
      if (selectedEl) break;
    }

    q(document, 'link[rel*="style"][title]', el => {
      if (!selectedEl) selectedEl = el; // Fallback
      el.disabled = true; // Not sure why, but this seems to bee required by firefox
      el.disabled = el.href == selectedEl.href ? false : true;
      el.setAttribute('media', el == selectedEl ? '' : 'none');
      el.setAttribute('rel', el == selectedEl ? 'stylesheet' : 'alternate stylesheet');
    });
  }
}
