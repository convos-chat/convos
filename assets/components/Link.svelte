<script>
import {gotoUrl, pathname} from '../store/router';

let className = '';
let classNames = [];
let el;

export {className as class};
export let href = '/';
export let replace = false;
export let style = '';

export const focus = () => el.focus();

$: calculateClassNames(className, href, $pathname);

function calculateClassNames(className, href, $pathname) {
  classNames = className ? [className] : [];
  if ($pathname == href.replace(/(#|\?).*/, '')) classNames = [...classNames, 'has-path'];
}

function onClick(event) {
  gotoUrl(event.target.closest('a').href, {event, replace});
}
</script>

<a {href} on:click="{onClick}" class="{classNames.join(' ')}" style="{style}" bind:this="{el}"><slot/></a>
