import Reactive from '../js/Reactive';

export default class CommandHistory extends Reactive {
  constructor(params) {
    super();
    this.prop('persist', 'history', [], {key: 'command_history'});
    this.prop('rw', 'conversation', null);
    this.prop('rw', 'index', -1);
  }

  add(str) {
    if (!str.length) return this;
    const history = this.history.slice(0, 19);
    history.unshift(str);
    return this.update({history, index: -1});
  }

  attach(inputEl) {
    this.inputEl = inputEl;
  }

  render(e, index) {
    index = this.index + index;
    if (index < -1) index = -1;
    if (index >= this.history.length) index = this.history.length - 1;

    const curr = this.inputEl.value;
    if (this.inputEl.selectionStart != curr.length) {
      return false; // Disable history mode if the cursor is inside the text
    }
    if (curr.length && curr != this.history[this.index]) {
      return false; // Disable history mode if the string has been changed
    }

    e.preventDefault();
    this.update({index});
    this.inputEl.value = index == -1 ? '' : this.history[index];
    return true;
  }

  update(params) {
    if (params.conversation && params.conversation != this.conversation) this.update({index: -1});
    return super.update(params);
  }
}
