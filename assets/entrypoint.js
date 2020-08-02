import './sass/convos.scss';
import App from './App.svelte';
import hljs from './js/hljs';
import {q, removeChildNodes} from './js/util';

const body = document.querySelector('body');
body.classList = body.className.replace(/no-js/, 'has-js');

q(document, '#hamburger_checkbox_toggle', el => { el.checked = false });

const appContainer = document.querySelector('.app-container');
if (appContainer) {
  removeChildNodes(appContainer);
  const app = new App({target: appContainer});
}
else {
  document.addEventListener('DOMContentLoaded', function(e) {
    q(document, 'pre', el => hljs.lineNumbersBlock(el));
  });
}
