import {writable} from '../js/storeGenerator';

export const activeMenu = writable('', {
  toggle(e) {
    e.preventDefault();
    const aEl = e.target.closest('a');
    const name = aEl && aEl.href.replace(/.*#/, '');
    this.set(this.get() == name ? '' : name);
  },
});

export const viewport = writable({leftColumn: false, rightColumn: false, singleColumn: true, width: 0}, {
  setWidth(width) {
    const leftColumn = width >= 800;
    const rightColumn = width >= 1200;
    const singleColumn = leftColumn || rightColumn ? false : true;
    this.set({leftColumn, rightColumn, singleColumn, width});
  },
});
