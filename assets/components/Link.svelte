<script>
import {gotoUrl, currentUrl} from '../store/router';

let className = '';
let classNames = [];
let el;

export {className as class};
export let href = '/';
export let native = false;
export let replace = false;
export let style = '';
export let title = '';

export const focus = () => el.focus();

$: absoluteHref = href.slice(0, 1) == '/' ? currentUrl.base + href : href;

function onClick(event) {
  if (!native) gotoUrl(event.target.closest('a').href, {event, replace});
}
</script>

<a href="{absoluteHref}" on:click="{onClick}" class="{className}" class:has-path="{$currentUrl == absoluteHref.replace(/(#|\?).*/, '')}" style="{style}" title="{title}" bind:this="{el}"><slot/></a>
