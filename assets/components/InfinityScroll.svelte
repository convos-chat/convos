<script>
import {createEventDispatcher} from 'svelte';
import {findVisibleElements, isType} from '../js/util';

const dispatch = createEventDispatcher();
const state = {scrollDelay: 80, scrollOffset: 80, scrollTop: 0};

let className = '';
let isManuallyScrolled = true;
let scrollHeight = 0;

export {className as class};
export let pos = 'top';

$: classNames = [className || 'infinity-scroll'].concat(['has-pos-' + pos]);

function calculateDetails(infinityEl) {
  pos = infinityEl.scrollTop > scrollHeight - infinityEl.offsetHeight - state.scrollOffset ? 'bottom'
      : infinityEl.scrollTop < state.scrollOffset ? 'top'
      : 'middle';

  state.pos = pos;
  state.visibleEls = findVisibleElements(infinityEl.firstElementChild, infinityEl);
}

function onReady(infinityEl, params) {
  state.infinityEl = infinityEl;
  state.scrollTo = scrollTo;
  infinityEl.addEventListener('scroll', () => onScroll(infinityEl));
  calculateDetails(infinityEl);
  onUpdate(infinityEl, params);
  return {update: (params) => onUpdate(infinityEl, params)};
}

function onScroll(infinityEl) {
  if (state.scrollTid) clearTimeout(state.scrollTid);
  if (Math.abs(state.scrollTop - state.infinityEl.scrollTop) > 600) onScrolled(infinityEl); // 600 is a more or less randomly picked number
  state.scrollTid = setTimeout(() => onScrolled(infinityEl), state.scrollDelay);
}

function onScrolled(infinityEl) {
  if (isManuallyScrolled) return (isManuallyScrolled = false);
  state.scrollTop = infinityEl.scrollTop;
  calculateDetails(infinityEl);
  dispatch('scrolled', state);
}

function onUpdate(infinityEl, {scrollHeight}) {
  const emitRendered = state.scrollHeight != scrollHeight;
  state.scrollHeight = scrollHeight;
  calculateDetails(infinityEl);
  if (emitRendered) dispatch('rendered', state);
}

function scrollTo(pos) {
  if (isType(pos, 'undef')) return false;
  if (pos == -1) pos = scrollHeight - pos;
  if (isType(pos, 'string')) pos = state.infinityEl.querySelector(pos);
  if (pos && pos.tagName) pos = pos.offsetTop;
  if (isType(pos, 'undef')) return false;
  isManuallyScrolled = true;
  state.infinityEl.scrollTop = pos;
  return true;
}
</script>

<main class="{classNames.join(' ')}" use:onReady="{{scrollHeight}}">
  <div bind:offsetHeight="{scrollHeight}"><slot/></div>
</main>
