import Time from '../js/Time';
import {lmd, topicOrStatus} from '../js/i18n';
import {urlFor} from '../store/router';

function fillIn(message) {
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

const internalMessages = {};

internalMessages.askForNotifications = (user) => {
  const messages = [];
  if (user.events.wantNotifications !== null) return messages;

  messages.push(fillIn({
    message: 'Do you want notifications when someone sends you a private message? [Yes](%1) / [No](%2)',
    vars: ['#call:events:requestPermissionToNotify', '#call:events:rejectNotifications'],
  }));

  return messages;
};

internalMessages.fillIn = fillIn;

internalMessages.firstTime = (user, dialog) => {
  const messages = [];
  const firstTime = dialog && dialog.is && dialog.is('conversation') && dialog.first_time;
  if (!firstTime) return messages;

  if (!dialog.is_private) {
    messages.push(fillIn({
      message: dialog.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.',
      type: 'notice',
      vars: [dialog.name, dialog.topic],
    }));
  }

  if (dialog.is_private) {
    messages.push(fillIn({
      message: 'This is a private conversation with [%1](%2).',
      type: 'notice',
      vars: [dialog.name, urlFor(dialog.path + '#send:' + encodeURIComponent('/whois ' + dialog.name))],
    }));
  }
  else {
    const nParticipants = dialog.participants().length;
    messages.push(fillIn({
      message: nParticipants == 1 ? 'You are the only participant in this conversation.' : 'There are %1 [participants](%2) in this conversation.',
      type: 'notice',
      vars: [nParticipants, urlFor(dialog.path + '#activeMenu:settings')],
    }));
  }

  if (user.dialogs().length <= 3) {
    messages.push(fillIn({
      message: 'Start chatting by writing a message in the input field, or click on the conversation name ([%1](%2)) to get more information.',
      type: 'notice',
      vars: [dialog.name, urlFor(dialog.path + '#activeMenu:settings')],
    }));
  }

  return messages;
};

internalMessages.connectionDialogStatus = (connection, dialog) => {
  const messages = [];
  if (!connection.is || connection.is('unreachable')) return messages;

  if (connection.frozen) {
    messages.push(fillIn({
      message: 'Disconnected. Your connection %1 can be edited in [settings](%2).',
      vars: [connection.name, urlFor(connection.path + '#activeMenu:settings')],
    }));
  }
  else if (dialog.frozen && !dialog.is('locked')) {
    messages.push(fillIn({message: topicOrStatus(connection, dialog).replace(/\.$/, ''), vars: []}));
  }

  return messages;
};

internalMessages.emptySearch = (user, dialog) => {
  const messages = [];
  if (!dialog.is('search')) return messages;

  if (dialog.query === null) {
    messages.push(fillIn({
      message: 'Search for messages sent by you or others the last %1 days by writing a message in the input field below.',
      type: 'notice',
      vars: [90],
    }));
    messages.push(fillIn({
      message: 'You can enter a channel name, or use `"conversation:#channel"` to narrow down the search.',
      type: 'notice',
      vars: [dialog.name, urlFor(dialog.path + '#activeMenu:settings')],
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
};

internalMessages.mergeWithMessages = (user, connection, dialog) => {
  return internalMessages.emptySearch(user, dialog)
    .concat(internalMessages.firstTime(user, dialog))
    .concat(dialog.messages)
    .concat(internalMessages.connectionDialogStatus(connection, dialog))
    .concat(internalMessages.askForNotifications(user));
};

export default internalMessages;
