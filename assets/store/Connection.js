import ConnURL from '../js/ConnURL';
import Dialog from './Dialog';
import {ro, sortByName} from '../js/util';

export default class Connection extends Dialog {
  constructor(params) {
    super(params);

    this.channels = [];
    this.private = [];
    this.url = typeof params.url == 'string' ? new ConnURL(params.url) : params.url;

    ro(this, 'isConnection', true);

    Object.defineProperty(this, 'nick', {
      get: () => this.url.searchParams.get('nick') || '',
      set: (val) => {
        this.url.searchParams.set('nick', val);
        this._notifySubscribers();
      },
    });
  }

  dialogs() {
    return this.channels.concat(this.private);
  }

  ensureDialog(params) {
    let dialog = this.dialogs().filter(dialog => dialog.id == params.dialog_id)[0];
    if (dialog) return dialog.update(params);

    dialog = new Dialog({...params, api: this.api});
    const listName = dialog.is_private ? 'private' : 'channels';
    this[listName] = this[listName].concat(dialog).sort(sortByName);
    this._notifySubscribers();
    return dialog;
  }

  findDialog(params) {
    return this.dialogs().filter(dialog => dialog.id == params.dialog_id)[0];
  }
}