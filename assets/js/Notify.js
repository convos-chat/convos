import {getLogger} from './logger';
import Reactive from './Reactive';

const log = getLogger('notify');

export default class Notify extends Reactive {
  constructor() {
    super();
    this.Notification = window.Notification || {permission: 'denied'};
    this.prop('persist', 'volume', 0); // {0..100}
    this.prop('persist', 'notificationCloseDelay', 5000);
    this.prop('persist', 'wantNotifications', this.Notification.requestPermission ? null : false);
    this.prop('ro', 'appHasFocus', () => document.hasFocus());
    this.prop('ro', 'volumeOptions', [['0', 'Muted'], ['25', 'Low'], ['50', 'Medium'], ['100', 'Max']]);
    this.prop('rw', 'desktopAccess', this.Notification.permission);
  }

  play(params = this) {
    const el = document.getElementById('audio_notification');
    if (!el) return;
    el.muted = false;
    el.volume = parseInt(params.volume, 10) / 100;
    el.play();
  }

  requestDesktopAccess() {
    if (!this.Notification.requestPermission) return this.update({desktopAccess: this.Notification.permission});
    this.Notification.requestPermission((permission) => this.update({desktopAccess: permission}));
    return this;
  }

  show(message, params = {}) {
    if (!params.title) params.title = document.title;
    if (!this.wantNotifications) return this._showInConsole(message, params);
    if (this.volume) this.play();
    if (this.desktopAccess != 'granted') return this.showInApp(message, params);

    const notification = new Notification(params.title, {...params, body: message});
    notification.onclick = (e) => this._onClick(e, notification, params);
    setTimeout(() => notification.close(), this.notificationCloseDelay);
    return notification;
  }

  showInApp(message, params = {}) {
    if (!params.title) params.title = document.title;

    const el = document.createElement('div');
    const notification = {
      ...params,
      body: message,
      close: () => { el.remove(); notification.closed = true },
      target: 'app',
    };

    el.className = 'notify-notification fade-in';
    el.innerHTML = '<a href="#close" class="notify-notification__close"></a><h6 class="notify-notification__title"></h6><div class="notify-notification__content"></div>';
    el.querySelector('a').addEventListener('click', (e) => { e.preventDefault(); notification.close() });
    el.querySelector('h6').textContent = params.title;
    el.querySelector('div').textContent = message;

    if (params.closeAfter == -1) {
      el.querySelector('a').remove();
    }
    else {
      setTimeout(() => notification.close(), params.closeAfter || this.notificationCloseDelay);
    }

    setTimeout(() => el.classList.add('is-visible'), 1);
    document.body.appendChild(el);
    return notification;
  }

  _onClick(e, notification, params) {
    notification.close();
    window.focus();
    this.emit('click', {...params, sourceEvent: e});
  }

  _showInConsole(message, params) {
    log.info('[Notify]', message, params);
    return {...params, body: message, close: () => {}, target: 'console'};
  }
}

export const notify = new Notify();
