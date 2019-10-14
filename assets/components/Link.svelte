<script>
import {gotoUrl, pathname} from '../store/router';

export let className = '';
export let href = '/';
export let replace = false;
export let style = '';

export const focus = () => el.focus();

let classNames = [];
let el;

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
