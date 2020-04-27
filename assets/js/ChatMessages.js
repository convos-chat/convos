import Time from '../js/Time';
import {lmd, topicOrStatus} from '../js/i18n';
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
    const classes = ['message', 'is-type-' + message.type];

    if (message.from == this.connection.nick) classes.push('is-sent-by-you');
    if (message.highlight) classes.push('is-highlighted');

    const dayChanged = this.dayChanged(messages, i);
    const isSameSender = i == 0 ? false : messages[i].fromId == messages[i - 1].fromId;
    if (!dayChanged && isSameSender) classes.push('has-same-from');
    if (!dayChanged && !isSameSender) classes.push('has-not-same-from');

    const isOnline = this.isOnline(message);
    if (!isOnline) classes.push('is-not-present');

    return classes.join(' ');
  }

  connectionDialogStatus() {
    const connection = this.connection;
    const dialog = this.dialog;
    if (!connection.is || connection.is('unreachable')) return [];

    const messages = [];
    if (connection.frozen) {
      messages.push(this.fillIn({
        message: 'Disconnected. Your connection %1 can be edited in [settings](%2).',
        vars: [connection.name, route.urlFor(connection.path + '#activeMenu:settings')],
      }));
    }
    else if (dialog.frozen && !dialog.is('locked')) {
      messages.push(this.fillIn({message: topicOrStatus(connection, dialog).replace(/\.$/, ''), vars: []}));
    }

    return messages;
  }

  dayChanged(messages, i) {
    return !messages.length ? false
         : i == 0 ? this.dialog.is('search')
         : messages[i].ts.getDate() != messages[i - 1].ts.getDate();
  }

  fillIn(message) {
    return {
      color: 'inherit',
      from: 'Convos',
      fromId: 'Convos',
      markdown: lmd(message.message, ...message.vars),
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

  firstTime() {
    const dialog = this.dialog;
    const firstTime = dialog && dialog.is && dialog.is('conversation') && dialog.first_time;
    if (!firstTime) return [];

    const messages = [];
    if (!dialog.is_private) {
      messages.push(this.fillIn({
        message: dialog.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.',
        type: 'notice',
        vars: [dialog.name, dialog.topic],
      }));
    }

    if (dialog.is_private) {
      messages.push(this.fillIn({
        message: 'This is a private conversation with %1.',
        type: 'notice',
        vars: [dialog.name],
      }));
    }
    else {
      const nParticipants = dialog.participants().length;
      messages.push(this.fillIn({
        message: nParticipants == 1 ? 'You are the only participant in this conversation.' : 'There are %1 [participants](%2) in this conversation.',
        type: 'notice',
        vars: [nParticipants, route.urlFor(dialog.path + '#activeMenu:settings')],
      }));
    }

    if (this.user.dialogs().length <= 3) {
      messages.push(this.fillIn({
        message: 'Start chatting by writing a message in the input field, or click on the conversation name ([%1](%2)) to get more information.',
        type: 'notice',
        vars: [dialog.name, route.urlFor(dialog.path + '#activeMenu:settings')],
      }));
    }

    return messages;
  }

  merge(messages) {
    return this.emptySearch().concat(this.firstTime()).concat(messages).concat(this.connectionDialogStatus());
  }
}
