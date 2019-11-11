import {themes} from '../settings';

let osTheme = 'dark';

const matchMedia = window.matchMedia('(prefers-color-scheme: dark)');
if (matchMedia.matches) osTheme = 'dark';
matchMedia.addListener(e => { osTheme = e.matches ? 'dark' : 'light' });

export function setTheme(name) {
  if (themes.filter(t => t[0] == name).length == 0) name = 'auto';
  if (name == 'auto') name = osTheme;
  const html = document.documentElement;
  html.className = html.className.replace(/theme-\S+/, () => 'theme-' + name);
}
