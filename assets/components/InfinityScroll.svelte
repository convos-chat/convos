<script>
import now from 'lodash/now';
import {createEventDispatcher} from 'svelte';
import {findVisibleElements, is} from '../js/util';

const dispatch = createEventDispatcher();
const state = {scrollDelay: 80, scrollOffset: 80, scrollTop: 0, visibleEls: []};

let className = '';
let scrolledAt = now();
let scrollHeight = 0;

export {className as class};
export let pos = 'top';

$: classNames = [className || 'infinity-scroll'].concat(['has-pos-' + pos]);
$: scrollHeight && calculateDetails();

function calculateDetails() {
  const infinityEl = state.infinityEl;
  if (!infinityEl) return;

  pos = infinityEl.scrollTop > scrollHeight - infinityEl.offsetHeight - state.scrollOffset ? 'bottom'
      : infinityEl.scrollTop < state.scrollOffset ? 'top'
      : 'middle';

  state.pos = pos;
  state.scrollHeightChanged = state.scrollHeight !== scrollHeight;
  state.scrollHeight = scrollHeight;
  state.visibleElsChanged = false;

  const visibleEls = findVisibleElements(infinityEl.firstElementChild, infinityEl);
  if (visibleEls.length !== state.visibleEls.length || visibleEls[0] !== state.visibleEls[0]) {
    state.visibleEls = visibleEls;
    state.visibleElsChanged = true;
  }

  if (state.scrollHeightChanged || state.visibleElsChanged) dispatch('visibility', state);
  if (state.scrollHeightChanged) dispatch('rendered', state);
}

function onReady(infinityEl) {
  state.infinityEl = infinityEl;
  state.scrollTo = scrollTo;
  infinityEl.addEventListener('scroll', () => onScroll(infinityEl));
  calculateDetails();
}

function onScroll(infinityEl) {
  if (state.scrollTid) clearTimeout(state.scrollTid);
  state.scrollTid = setTimeout(() => onScrolled(infinityEl), state.scrollDelay);
}

function onScrolled(infinityEl) {
  if (scrolledAt + 500 > now()) {
    // onScrolled() gets triggered when scrollTo() changes infinityEl.scrollTop.
    // Need to cancel the next "scroll" event as well, in case "scrollTop" was not set correctly.
    if (Math.abs(infinityEl.scrollTop - state.scrollTop) > 40) infinityEl.scrollTop = state.scrollTop;
    if (state.scrollTid) clearTimeout(state.scrollTid);
    calculateDetails();
  }
  else {
    state.scrollTop = infinityEl.scrollTop;
    calculateDetails();
    dispatch('scrolled', state);
  }
}

function scrollTo(pos) {
  if (is.undefined(pos)) return false;
  if (pos === -1) pos = scrollHeight;
  if (is.string(pos)) pos = state.infinityEl.querySelector(pos);
  if (pos && pos.tagName) pos = pos.offsetTop;
  if (is.undefined(pos)) return false;
  if (pos < 0) return false;
  scrolledAt = now();
  state.infinityEl.scrollTop = pos;
  state.scrollTop = state.infinityEl.scrollTop;
  return true;
}
</script>

<main class="{classNames.join(' ')}" use:onReady>
  <div bind:offsetHeight="{scrollHeight}"><slot/></div>
</main>
