import './sass/convos.scss';
import App from './App.svelte';

console.log('[Convos] Initializing application.');

const body = document.querySelector('body');
const removeEls = document.querySelectorAll('.js-remove');
const app = new App({target: document.body});

body.classList.remove('no-js');
for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', e => {
    navigator.serviceWorker.register('/sw.js').then(
      (reg) => window.updateServiceWorker && reg.update(),
      (err) => console.log('[Convos] ServiceWorker registration failed:', err),
    );
  });
}