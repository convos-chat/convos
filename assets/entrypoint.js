import './sass/convos.scss';
import App from './App.svelte';
import hljs from './js/hljs';
import {removeChildNodes} from './js/util';

const body = document.querySelector('body');
body.classList = body.className.replace(/no-js/, 'has-js');
window.hljs = hljs;

const appContainer = document.querySelector('.app-container');
if (appContainer) {
  removeChildNodes(appContainer);
  const app = new App({target: appContainer});
}
