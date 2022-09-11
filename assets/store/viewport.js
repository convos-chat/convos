import {writable} from '../js/storeGenerator';

export const activeMenu = writable('', {
  toggle(e) {
    e.preventDefault();
    const aEl = e.target.closest('a');
    const name = aEl && aEl.href.replace(/.*#/, '');
    this.set(this.get() == name ? '' : name);
  },
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
