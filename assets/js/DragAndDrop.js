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

    this.pasteEvents = {
      paste: this.paste.bind(this),
    };

    this.dropIndicatorEl = document.createElement('div');
    this.dropIndicatorEl.className = 'drop-area hidden';
    this.removeDragOverDebounced = debounce(() => this._removeDragOver(), 100);
  }

  attach(dropEl, uploader, targetEl = document) {
    this.dropEl = dropEl;
    this.uploader = uploader;
    this.targetEl = targetEl;

    Object.keys(this.dragAndDropEvents).forEach(name => {
      targetEl.addEventListener(name, this.dragAndDropEvents[name]);
    });

    Object.keys(this.pasteEvents).forEach(name => {
      document.addEventListener(name, this.pasteEvents[name]);
    });
  }

  detach() {
    Object.keys(this.dragAndDropEvents).forEach(name => {
      this.targetEl.removeEventListener(name, this.dragAndDropEvents[name]);
    });
    Object.keys(this.pasteEvents).forEach(name => {
      document.removeEventListener(name, this.pasteEvents[name]);
    });
  }

  drop(e) {
    this.stop(e);
    if (this.uploader) this.uploader(e);
  }

  paste(e) {
    const items = (e.clipboardData || e.originalEvent.clipboardData).items;
    if (!this.uploader) return;

    for (let i = 0; i < items.length; i++) {
      if (items[i].kind != 'file') continue;
      return this.uploader({dataTransfer: {files: [items[i].getAsFile()]}});
    }
  }

  stop(e) {
    this._preventDefault(e);
    this.removeDragOverDebounced();
  }

  start(e) {
    if (!this.dropEl) return;
    this._preventDefault(e);
    const style = this.dropIndicatorEl.style;
    style.height = this.dropEl.offsetHeight + 'px';
    style.width = this.dropEl.offsetWidth + 'px';
    style.top = this.dropEl.offsetTop + 'px';
    style.left = this.dropEl.offsetLeft + 'px';
    this.dropIndicatorEl.classList.remove('hidden');
    this.dropEl.parentNode.appendChild(this.dropIndicatorEl);
  }

  _preventDefault(e) {
    e.preventDefault();
    e.stopPropagation();
  }

  _removeDragOver() {
    this.dropIndicatorEl.classList.add('hidden');
  }
}
