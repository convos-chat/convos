<script>
import {hrefToPathname, pathname} from '../store/router';

export let className = '';
export let href = '/';
export let replace = false;

let classNames = [];
pathname.subscribe($pathname => {
  classNames = className ? [className] : [];
  if (href.indexOf($pathname) == 0) classNames = [...classNames, 'has-basepath'];
  if ($pathname == href.replace(/\#/, '')) classNames = [...classNames, 'has-path'];
  if ($pathname == href) classNames = [...classNames, 'is-exact'];
});

function onClick(e) {
  const aEl = e.target.closest('a');
  if (hrefToPathname(aEl.href) === null) return;
  e.preventDefault();
  history[replace ? 'replaceState' : 'pushState']({}, document.title, aEl.href);
}
</script>

<a {href} on:click={onClick} class={classNames.join(' ')}><slot/></a>
