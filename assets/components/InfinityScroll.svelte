<script>
import {createEventDispatcher} from 'svelte';
import {findVisibleElements, isType} from '../js/util';

const DEBUG = false;
const dispatch = createEventDispatcher();
const state = {scrollDelay: 80, scrollOffset: 80, scrollTop: 0};

let cancelNextScroll = true;
let className = '';
let scrollHeight = 0;

export {className as class};
export let pos = 'top';

$: classNames = [className || 'infinity-scroll'].concat(['has-pos-' + pos]);
$: DEBUG && console.log(location.href + ': ' + scrollHeight);

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
  state.scrollTid = setTimeout(() => onScrolled(infinityEl), state.scrollDelay);
}

function onScrolled(infinityEl) {
  if (DEBUG) console.log('onScrolled pos=' + state.scrollTop + '/' + infinityEl.scrollTop + ' cancelNextScroll=' + cancelNextScroll);

  if (cancelNextScroll) {
    // onScrolled() can will get triggered when scrollTo() changes infinityEl.scrollTop.
    // Need to cancel the next "scroll" event as well, in case "scrollTop" was not set correctly.
    cancelNextScroll = Math.abs(infinityEl.scrollTop - state.scrollTop) > 40;
    if (cancelNextScroll) infinityEl.scrollTop = state.scrollTop;
    if (state.scrollTid) clearTimeout(state.scrollTid);
    return;
  }

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
  if (pos == -1) pos = scrollHeight;
  if (isType(pos, 'string')) pos = state.infinityEl.querySelector(pos);
  if (pos && pos.tagName) pos = pos.offsetTop;
  if (isType(pos, 'undef')) return false;
  if (pos < 0) return false;
  cancelNextScroll = true;
  state.infinityEl.scrollTop = pos;
  state.scrollTop = state.infinityEl.scrollTop;
  if (DEBUG) console.log('scrollTo pos=' + pos + '/' + state.scrollTop);
  return true;
}
</script>

<main class="{classNames.join(' ')}" use:onReady="{{scrollHeight}}">
  <div bind:offsetHeight="{scrollHeight}"><slot/></div>
</main>
