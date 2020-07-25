import Reactive from './Reactive';
import {l} from '../js/i18n';

export default class Notify extends Reactive {
  constructor() {
    super();
    this.Notification = window.Notification || {permission: 'denied'};
    this.prop('persist', 'notificationCloseDelay', 5000);
    this.prop('persist', 'wantNotifications', null);
    this.prop('ro', 'appHasFocus', () => document.hasFocus());
    this.prop('rw', 'desktopAccess', this.Notification.permission);
  }

  requestDesktopAccess() {
    if (!this.Notification.requestPermission) return this.update({desktopAccess: this.Notification.permission});
    this.Notification.requestPermission((permission) => this.update({desktopAccess: permission}));
    return this;
  }

  show(message, params = {}) {
    if (!params.title) params.title = document.title;
    const cannotShowOnDesktop = this._cannotShowOnDesktop(params);
    return cannotShowOnDesktop ? this._showInConsole(message, {...params, cannotShowOnDesktop}) : this._showOnDesktop(message, params);
  }

  _cannotShowOnDesktop(params = {}) {
    if (this.desktopAccess != 'granted') return this.Notification.permission || 'unknown';
    if (!this.wantNotifications) return '!wantNotifications';
    return '';
  }

  _onClick(e, notification, params) {
    notification.close();
    window.focus();
    this.emit('click', {...params, sourceEvent: e});
  }

  _showInConsole(message, params) {
    console.info('[Notify]', message, params);
    return {...params, body: message, close: () => {}};
  }

  _showOnDesktop(message, params) {
    const notification = new Notification(params.title, {...params, body: message});
    notification.onclick = (e) => this._onClick(e, notification, params);
    setTimeout(() => notification.close(), this.notificationCloseDelay);
    return notification;
  }
}

export const notify = new Notify();
