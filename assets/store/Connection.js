import ConnURL from '../js/ConnURL';
import Dialog from './Dialog';
import {sortByName} from '../js/util';

export default class Connection extends Dialog {
  constructor(params) {
    super(params);

    this._updateableAttr('on_connect_commands', params.on_connect_commands || '');
    this._updateableAttr('state', params.state || 'queued');
    this._updateableAttr('wanted_state', params.wanted_state || 'connected');
    this._updateableAttr('url', typeof params.url == 'string' ? new ConnURL(params.url) : params.url);

    // Dialogs by category
    this._updateableAttr('channels', []);
    this._updateableAttr('private', []);

    // Proxy attribute
    Object.defineProperty(this, 'nick', {
      get: () => this.url.searchParams.get('nick') || '',
      set: (val) => { this.url.searchParams.set('nick', val); this.update({}) },
    });
  }

  dialogs() {
    return this.channels.concat(this.private);
  }

  ensureDialog(params) {
    let dialog = this.dialogs().filter(dialog => dialog.dialog_id == params.dialog_id)[0];

    if (dialog) {
      this.update({});
      return dialog.update(params);
    }

    dialog = new Dialog({...params, api: this.api});
    const listName = dialog.is_private ? 'private' : 'channels';
    this.update({[listName]: this[listName].concat(dialog).sort(sortByName)});
    return dialog;
  }

  findDialog(params) {
    return this.dialogs().filter(dialog => dialog.dialog_id == params.dialog_id)[0];
  }

  removeDialog(params) {
    return this.update({
      channels: this.channels.filter(d => d.dialog_id != params.dialog_id),
      private: this.private.filter(d => d.dialog_id != params.dialog_id),
    });
  }
}