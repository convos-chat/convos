import './sass/convos.scss';
import App from './App.svelte';

const removeEls = document.querySelectorAll('.js-remove');
const app = new App({target: document.body});

for (let i = 0; i < removeEls.length; i++) removeEls[i].remove();