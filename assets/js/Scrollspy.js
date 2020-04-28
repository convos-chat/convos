import Reactive from './Reactive';

export default class Scrollspy extends Reactive {
  constructor() {
    super();
    this.scrollTo = this.scrollTo.bind(this);
    this.wrapper = null;
  }

  observe(selector) {
    if (!this.wrapper) return;

    if (!this.observer) {
      const cb = (entries) => entries.forEach(entry => this.emit('observed', entry));
      this.observer = new IntersectionObserver(cb, {rootMargin: '0px'});
    }

    this.observer.disconnect();
    const els = this.wrapper.querySelectorAll(selector);
    for (let i = 0; i < els.length; i++) this.observer.observe(els[i]);
  }

  scrollTo(to, guard = 0) {
    if (guard >= 5) return; // Give up
    if (!this.wrapper) return setTimeout(() => this.scrollTo(to, guard + 1), 20);

    if (typeof to == 'number') {
      this.wrapper.scrolledByCode = true;
      return (this.wrapper.scrollTop = to);
    }

    if (typeof to == 'string') {
      const el = document.querySelector(to);
      return el ? this.scrollTo(el, 0) : setTimeout(() => this.scrollTo(to, guard + 1), 20);
    }

    if (to.href && to.href.indexOf('#') != -1) {
      location.hash = to.href.replace(/.*#/, '#');
      return this.scrollTo(location.hash);
    }

    if (to.tagName) return this.scrollTo(to.offsetTop - 30); // Cannot scroll all the way to element, because of header
    if (to.preventDefault) to.preventDefault();
    if (to.target && to.target.tagName) return this.scrollTo(to.target.closest('[href]'));

    throw 'Cannot scroll to ' + to;
  }
}
