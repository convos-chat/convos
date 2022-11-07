import debounce from 'lodash/debounce';
import {derived, readable} from 'svelte/store';
import {localstorage} from './localstorage';
import {writable} from '../js/storeGenerator';

export const activeMenu = writable('', {
  toggle(e) {
    e.preventDefault();
    const aEl = e.target.closest('a');
    const name = aEl && aEl.href.replace(/.*#/, '');
    this.set(this.get() === name ? '' : name);
  },
});

export const showConversationSettings = localstorage('showConversationSettings', false);
export const showParticipants = localstorage('showParticipants', true);

export const width = readable(0, (set) => {
  set(window.innerWidth);
  window.addEventListener('resize', debounce(() => set(window.innerWidth), 150));
});

export const hasRightColumn = derived([showConversationSettings, showParticipants, width], ([showConversationSettings, showParticipants, width]) => {
  return width >= 1200 && (showConversationSettings || showParticipants);
});

export const viewport = writable(
  {
    hasLeftColumn: false,
    hasRightColumn: false,
    isSingleColumn: true,
    width: 0,
  },
  {
    setWidth(width) {
      const hasLeftColumn = width >= 800;
      const hasRightColumn = width >= 1200;
      const isSingleColumn = hasLeftColumn || hasRightColumn ? false : true;
      this.set({hasLeftColumn, hasRightColumn, isSingleColumn, width});
    },
  },
);
