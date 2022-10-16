import Notify from '../assets/js/Notify';
import {expect, test} from 'vitest';
import {timer} from '../assets/js/util';

global.Notification = function(title, params) {
  this.close = () => { this.closed = true };
  this.params = {...params};
  this.target = 'desktop';
  this.title = title;
  delete this.params.title;
};

global.Notification.permission = 'denied';

test('requestDesktopAccess', () => {
  const notify = new Notify();
  notify.requestDesktopAccess();
  expect(notify.desktopAccess).toBe('denied');

  notify.Notification.requestPermission = (cb) => cb('granted');
  notify.requestDesktopAccess();
  expect(notify.desktopAccess).toBe('granted');
});

test('cannot show', () => {
  const notify = new Notify();
  let notification;

  notification = notify.show('a');
  expect(notification.target).toBe('console');

  notify.update({wantNotifications: true});
  notification = notify.show('b');
  expect(notification.target).toBe('app');

  notify.Notification.requestPermission = (cb) => cb('granted');
  notify.requestDesktopAccess();
  notification = notify.show('b');
  expect(notification.target).toBe('desktop');
});

test('show', async () => {
  const notify = new Notify({wantNotifications: true});
  let notification;

  document.title = 'document title';
  notification = notify.show('some message');
  expect(notification.body).toBe('some message');
  expect(notification.title).toBe('document title');

  notify.update({desktopAccess: 'granted', notificationCloseDelay: 10, wantNotifications: true});
  notification = notify.show('desktop message');
  expect(notification.title).toBe('document title');
  expect(notification.params).toEqual({body: 'desktop message'});
  expect(notification.closed).toBe(undefined);
  expect(typeof notification.onclick).toBe('function');

  await timer(20);
  expect(notification.closed).toBe(true);
});
