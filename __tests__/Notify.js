import Notify from '../assets/js/Notify';
import {timer} from '../assets/js/util';

global.Notification = function(title, params) {
  this.close = () => { this.closed = true };
  this.params = {...params};
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

test('cannotShowOnDesktop', () => {
  const notify = new Notify();
  expect(notify._cannotShowOnDesktop()).toBe('denied');

  notify.Notification.requestPermission = (cb) => cb('granted');
  notify.requestDesktopAccess();
  expect(notify._cannotShowOnDesktop()).toBe('!wantNotifications');

  document.hasFocus = () => true;
  notify.update({wantNotifications: true});
  expect(notify._cannotShowOnDesktop()).toBe('hasFocus');
  expect(notify._cannotShowOnDesktop({force: true})).toBe('');

  document.hasFocus = () => false;
  expect(notify._cannotShowOnDesktop({})).toBe('');
});

test('show', async () => {
  const notify = new Notify();

  const consoleLog = [];
  document.title = 'document title';
  notify._showInConsole = (message, params) => consoleLog.push([message, params]);
  notify.show('some message');
  expect(consoleLog).toEqual([['some message', {title: 'document title', cannotShowOnDesktop: 'denied'}]]);
  consoleLog.pop();

  notify.update({desktopAccess: 'granted', notificationCloseDelay: 10, wantNotifications: true});
  notify.show('desktop message');
  expect(consoleLog).toEqual([]);
  expect(notify.notification.title).toBe('document title');
  expect(notify.notification.params).toEqual({body: 'desktop message'});
  expect(notify.notification.closed).toBe(undefined);
  expect(typeof notify.notification.onclick).toBe('function');

  await timer(20);
  expect(notify.notification.closed).toBe(true);
});
