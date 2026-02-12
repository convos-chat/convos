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
    this.prop('rw', 'pushEnabled', false);
    this.swRegistration = null;
  }

  async setServiceWorkerRegistration(reg) {
    this.swRegistration = reg;
    if (reg && reg.pushManager) {
      const sub = await reg.pushManager.getSubscription();
      this.update({pushEnabled: !!sub});
    }
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
    if (this.desktopAccess !== 'granted') return this.showInApp(message, params);
    if (this.pushEnabled && !this.appHasFocus) return this._showInConsole(message, params);

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

    if (params.closeAfter === -1) {
      el.querySelector('a').remove();
    }
    else {
      setTimeout(() => notification.close(), params.closeAfter || this.notificationCloseDelay);
    }

    setTimeout(() => el.classList.add('is-visible'), 1);
    document.body.appendChild(el);
    return notification;
  }

  async subscribeToPush(apiUrl) {
    const reg = this.swRegistration;
    if (!reg || !reg.pushManager) return log.info('[Notify] Push not supported');

    try {
      const res = await fetch(apiUrl + '/push/vapid');
      if (!res.ok) return log.info('[Notify] Failed to fetch VAPID key:', res.status);
      const {public_key} = await res.json();
      if (!public_key) return log.info('[Notify] No VAPID public key configured');

      const subscription = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(public_key),
      });

      const subJSON = subscription.toJSON();
      await fetch(apiUrl + '/push/subscribe', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          endpoint: subJSON.endpoint,
          keys: {auth: subJSON.keys.auth, p256dh: subJSON.keys.p256dh},
        }),
      });

      this.update({pushEnabled: true});
      log.info('[Notify] Push subscription registered');
    }
    catch (err) {
      log.info('[Notify] Push subscription failed:', err);
      this.update({pushEnabled: false});
    }
  }

  async unsubscribeFromPush(apiUrl) {
    const reg = this.swRegistration;
    if (!reg || !reg.pushManager) return;

    try {
      const subscription = await reg.pushManager.getSubscription();
      if (!subscription) return;

      const endpoint = subscription.endpoint;
      await subscription.unsubscribe();
      await fetch(apiUrl + '/push/unsubscribe', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({endpoint}),
      });

      this.update({pushEnabled: false});
      log.info('[Notify] Push subscription removed');
    }
    catch (err) {
      log.info('[Notify] Push unsubscribe failed:', err);
    }
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

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; i++) outputArray[i] = rawData.charCodeAt(i);
  return outputArray;
}

export const notify = new Notify();
