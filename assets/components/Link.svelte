<script>
import {gotoUrl, pathname} from '../store/router';

export let className = '';
export let href = '/';
export let replace = false;

export const focus = () => el.focus();

let classNames = [];
let el;

function calculateClassNames(href, $pathname) {
  classNames = className ? [className] : [];
  if (href.indexOf($pathname) == 0) classNames = [...classNames, 'has-basepath'];
  if ($pathname == href.replace(/#/, '')) classNames = [...classNames, 'has-path'];
  if ($pathname == href) classNames = [...classNames, 'is-exact'];
}

function onClick(event) {
  gotoUrl(event.target.closest('a').href, {event, replace})
}

$: calculateClassNames(href, $pathname);
</script>

<a {href} on:click={onClick} class={classNames.join(' ')} bind:this="{el}"><slot/></a>
