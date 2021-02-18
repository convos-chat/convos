import './sass/convos.scss';
import App from './App.svelte';
import Jitsi from './js/Jitsi';
import hljs from './js/hljs';
import {q, tagNameIs} from './js/util';

document.body.className = document.body.className.replace(/no-js/, 'has-js');
q(document, '#hamburger_checkbox_toggle', el => { el.checked = false });

q(document, '.js-close-window', el => {
  el.addEventListener('click', e => {
    if (!window.opener) return;
    e.preventDefault();
    setTimeout(() => window.close(), 1);
    window.opener.focus();
  });
});

if (document.querySelector('meta[name="convos:start_app"][content="chat"]')) {
  document.querySelector('.footer--wrapper').remove();
  document.querySelector('.cms-main').remove();
  const app = new App({target: document.body});
}
else if (document.querySelector('meta[name="convos:start_app"][content="jitsi"]')) {
  document.querySelector('.footer--wrapper').remove();
  const wrapper = document.querySelector('.cms-main');
  const app = new Jitsi(wrapper.dataset).render(wrapper);
}
else {
  document.addEventListener('DOMContentLoaded', function(e) {
    q(document, 'pre', el => hljs.lineNumbersBlock(el));
  });
}

// Global shortcuts
document.addEventListener('keydown', function(e) {
  // Esc
  if (e.keyCode == 27) {
    q(document, '.fullscreen', el => el.click());
    moveFocus();
  }

  // Shift+Enter
  if (e.keyCode == 13 && e.shiftKey) {
    e.preventDefault();
    moveFocus('toggle');
  }
});

// Like "load", but from ./store/Route.js
document.addEventListener('routerender', () => moveFocus());

function moveFocus(toggle) {
  if ('ontouchstart' in window) return;

  const firstEl = (sel) => {
    for (let i = 0; i < sel.length; i++) {
      const el = document.querySelector(sel[i]);
      if (el && el.tabIndex != -1) return el;
    }
    return null;
  };

  // Switch to menu item if main area item has focus
  const menuItem = toggle && firstEl(['input.is-primary-menu-item', 'a.is-primary-menu-item']);
  const targetEl = document.activeElement;
  if (tagNameIs(targetEl, ['a', 'input', 'textarea']) && menuItem && targetEl != menuItem) {
    return menuItem.focus();
  }

  // Try to focus elements in the main area
  const mainItem = firstEl(['.is-primary-input', 'main input[type="text"], article input[type="text"]', 'main a, article a']);
  if (mainItem) return mainItem.focus();

  // Fallback
  if (menuItem) return menuItem.focus();
}
