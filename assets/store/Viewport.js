import Reactive from '../js/Reactive';

export default class Viewport extends Reactive {
  constructor() {
    super();
    this.prop('rw', 'height', 0);
    this.prop('rw', 'width', 0);
    this.prop('ro', 'isWide', () => this.width > 800);
  }
}

export const viewport = new Viewport();
