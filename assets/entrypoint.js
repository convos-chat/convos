import './sass/convos.scss';
import App from './App.svelte';

const body = document.querySelector('body');
const app = new App({target: document.body});
body.classList = body.className.replace(/no-js/, 'has-js');