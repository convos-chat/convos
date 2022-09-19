<script>
import {route} from '../store/Route';

let className = '';
let el;

export {className as class};
export let href = '/';
export let style = '';

export const focus = () => el.focus();

$: absoluteHref = href.indexOf('/') === 0 ? $route.basePath + href : href;
$: hasPath = $route.basePath + $route.path === absoluteHref.replace(/(#|\?).*/, '');
</script>

<a href="{absoluteHref}" class="{className}" class:has-path="{hasPath}" style="{style}" bind:this="{el}" on:click><slot/></a>
