import {debounce} from './util';

export default class dragAndDrop {
  constructor() {
    this.dragAndDropEvents = {
      drag: this._preventDefault.bind(this),
      dragend: this.stop.bind(this),
      dragenter: this.start.bind(this),
      dragleave: this.stop.bind(this),
      dragover: this.start.bind(this),
      dragstart: this._preventDefault.bind(this),
      drop: this.drop.bind(this),
    };

    this.removeDragOverDebounced = debounce(() => this._removeDragOver(), 100);
  }

  attach(targetEl, dropEl, uploadEl) {
    if (this.targetEl) this.detach();

    this.dropEl = dropEl;
    this.uploadEl = uploadEl;
    this.targetEl = targetEl;

    Object.keys(this.dragAndDropEvents).forEach(name => {
      targetEl.addEventListener(name, this.dragAndDropEvents[name]);
    });
  }

  detach() {
    Object.keys(this.dragAndDropEvents).forEach(name => {
      this.targetEl.removeEventListener(name, this.dragAndDropEvents[name]);
    });
  }

  drop(e) {
    this.stop(e);
    if (this.uploadEl) this.uploadEl.uploader(e);
  }

  stop(e) {
    this._preventDefault(e);
    this.removeDragOverDebounced();
  }

  start(e) {
    this._preventDefault(e);
    if (this.dropEl) this.dropEl.classList.add('is-dragover');
  }

  _preventDefault(e) {
    e.preventDefault();
    e.stopPropagation();
  }

  _removeDragOver() {
    if (this.dropEl) this.dropEl.classList.remove('is-dragover');
  }
}
