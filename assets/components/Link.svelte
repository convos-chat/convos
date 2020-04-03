<script>
import {getContext} from 'svelte';
import {route} from '../store/Route';

let className = '';
let classNames = [];
let el;

export {className as class};
export let href = '/';
export let style = '';

export const focus = () => el.focus();

$: absoluteHref = href.slice(0, 1) == '/' ? $route.basePath + href : href;
$: hasPath = $route.canonicalPath.replace(/(#|\?).*/, '') == absoluteHref.replace(/(#|\?).*/, '');
</script>

<a href="{absoluteHref}" class="{className}" class:has-path="{hasPath}" style="{style}" bind:this="{el}"><slot/></a>
