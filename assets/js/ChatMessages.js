import Time from '../js/Time';
import {lmd} from '../js/i18n';
import {route} from '../store/Route';

export default class ChatMessages {
  attach({connection, dialog, user}) {
    this.connection = connection;
    this.dialog = dialog;
    this.user = user;
  }

  canToggleDetails(message) {
    return message.type == 'error' || message.type == 'notice';
  }

  classNames(messages, i) {
    const dialog = this.dialog;
    const message = messages[i];
    const classes = ['message'];

    const dayChanged = this.dayChanged(messages, i);
    const isSameSender = i == 0 ? false : messages[i].fromId == messages[i - 1].fromId;
    if (!dayChanged && isSameSender) classes.push('has-same-from');
    if (!dayChanged && !isSameSender) classes.push('has-not-same-from');

    if (message.hasOwnProperty('waitingForResponse')) {
      classes.push('is-sent-by-you');
      classes.push('is-waiting');
      classes.push(message.waitingForResponse ? 'is-type-notice' : 'is-type-error');
      return classes.join(' ');
    }

    if (message.type) classes.push('is-type-' + message.type);
    if (message.from == this.connection.nick) classes.push('is-sent-by-you');
    if (message.highlight) classes.push('is-highlighted');

    const isOnline = this.isOnline(message);
    if (!isOnline) classes.push('is-not-present');

    return classes.join(' ');
  }

  dayChanged(messages, i) {
    return !messages.length ? false
         : i == 0 ? this.dialog.is('search')
         : messages[i].ts.getDate() != messages[i - 1].ts.getDate();
  }

  fillIn(message) {
    return {
      color: 'inherit',
      from: message.waitingForResponse ? this.connection.nick : 'Convos',
      fromId: message.waitingForResponse ? this.connection.nick.toLowerCase() : 'Convos',
      markdown: lmd(message.message, ...(message.vars || [])),
      ts: new Time(),
      type: 'error',
      ...message,
    };
  }

  isOnline(message) {
    if (!this.dialog.connection_id) return true;
    if (message.fromId == 'Convos') return true;
    if (message.fromId == this.dialog.connection_id) return true;
    return this.dialog.findParticipant(message.fromId);
  }

  emptySearch() {
    const dialog = this.dialog;
    if (!dialog.is('search')) return [];

    const messages = [];
    if (dialog.query === null) {
      messages.push(fillIn({
        message: 'Search for messages sent by you or others the last %1 days by writing a message in the input field below.',
        type: 'notice',
        vars: [90],
      }));
      messages.push(fillIn({
        message: 'You can enter a channel name, or use `"conversation:#channel"` to narrow down the search.',
        type: 'notice',
        vars: [dialog.name, route.urlFor(dialog.path + '#activeMenu:settings')],
      }));
    }
    else if (!dialog.messages.length && dialog.is('success')) {
      messages.push(fillIn({
        message: 'No search results for "%1".',
        type: 'notice',
        vars: [dialog.query],
      }));
    }

    return messages;
  }

  merge(messages, waiting) {
    const waitingMessages = waiting.filter(msg => msg.method == 'send' && msg.message).map(msg => {
      msg = this.fillIn(msg);
      if (!msg.waitingForResponse) msg.markdown = lmd('Could not send message "%1".', msg.markdown);
      return msg;
    });
    return this.emptySearch().concat(messages).concat(waitingMessages);
  }
}
