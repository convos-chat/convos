import Connection from './Connection';
import ConnectionProfiles from './ConnectionProfiles';
import Conversation from './Conversation';
import Notifications from './Notifications';
import Reactive from '../js/Reactive';
import Search from './Search';
import SortedMap from '../js/SortedMap';
import camelCase from 'lodash/camelCase';
import debounce from 'lodash/debounce';
import {getSocket} from './../js/Socket';
import {notify} from './../js/Notify';
import {videoService} from './video';

export default class User extends Reactive {
  constructor(params) {
    super();

    this.prop('ro', 'connections', new SortedMap());
    this.prop('ro', 'connectionProfiles', new ConnectionProfiles());
    this.prop('ro', 'notifications', new Notifications({}));
    this.prop('ro', 'search', new Search({}));
    this.prop('ro', 'roles', new Set());

    this.prop('persist', 'ignoreStatuses', false);
    this.prop('persist', 'lastUrl', '');

    this.prop('rw', 'activeConversation', this.notifications);
    this.prop('rw', 'email', '');
    this.prop('rw', 'forced_connection', false);
    this.prop('rw', 'default_connection', 'irc://irc.libera.chat:6697/%23convos');
    this.prop('rw', 'highlightKeywords', []);
    this.prop('rw', 'id', '');
    this.prop('rw', 'status', 'pending');
    this.prop('rw', 'unreadIncludePrivateMessages', false);

    this.socket = params.socket || getSocket('/events');
    this.socket.on('message', (msg) => this._dispatchMessage(msg));
    this.socket.on('update', (socket) => this._onConnectionChange(socket));

    this.notifications.on('cleared', () => this._calculateUnread('clear'));
    this._calculateUnreadDebounced = debounce(this._calculateUnread, 25);

    // setInterval(() => this.socket.close(), 5000); // debug WebSocket reconnect issues
  }

  conversations(cb) {
    const conversations = [];

    this.connections.toArray().forEach(conn => {
      conn.conversations.toArray().forEach(conversation => {
        if (!cb || cb(conversation)) conversations.push(conversation);
      });
    });

    return conversations;
  }

  ensureConversation(params, _lock) {
    // Ensure channel or private conversation
    if (params.conversation_id) {
      const conn = this.ensureConversation({connection_id: params.connection_id}, true);
      return this._maybeUpgradeActiveConversation(conn.ensureConversation(params));
    }

    // Find connection
    let conn = this.findConversation(params);
    if (conn) return conn.update(params);

    // Create connection
    conn = new Connection({...params});

    // TODO: Figure out how to update Chat.svelte, without updating the user object
    conn.on('conversationadd', (conversation) => this._maybeUpgradeActiveConversation(conversation));
    conn.on('conversationremove', (conversation) => (conversation === this.activeConversation && this.setActiveConversation(conversation)));
    conn.on('update', () => this.update({connections: true}));
    conn.on('unread', () => this._calculateUnreadDebounced());
    this.connections.set(conn.connection_id, conn);
    this.update({connections: true});
    return _lock ? conn : this._maybeUpgradeActiveConversation(conn);
  }

  findConversation(params) {
    const conn = this.connections.get(params.connection_id);
    return !params.conversation_id ? conn : conn && conn.findConversation(params) || null;
  }

  is(statusOrRole) {
    if (Array.isArray(statusOrRole)) return !!statusOrRole.filter(sr => this.is(sr)).length;
    if (this.roles.has(statusOrRole)) return true;
    return this.status === statusOrRole;
  }

  async load() {
    if (this.is('loading')) return this;
    this.roles.clear();
    this.update({status: 'loading'});

    const p = new Promise(resolve => this.socket.send({method: 'load', object: 'user', params: {connections: true, conversations: true}}, resolve));
    const res = await p;

    // TODO: Improve error handling
    if (res.errors) {
      return this.update({email: '', roles: true, status: res.errors ? 'error' : 'success'});
    }

    const data = res.user || {};
    this.connections.clear();
    (data.connections || []).forEach(conn => this.ensureConversation({...conn, status: 'pending'}));
    (data.conversations || []).forEach(conversation => this.ensureConversation({...conversation, status: 'pending'}));
    (data.roles || []).forEach(role => this.roles.add(role));

    this.notifications.update({unread: data.unread || 0});
    videoService.fromString(data.video_service || '');

    return this.update({
      email: data.email || '',
      default_connection: data.default_connection || '',
      forced_connection: data.forced_connection || false,
      highlightKeywords: data.highlight_keywords || [],
      roles: true,
      status: res.errors ? 'error' : 'success',
      id: data.uid || '',
    });
  }

  removeConversation(params) {
    const conn = this.findConversation({connection_id: params.connection_id});
    if (params.conversation_id) return conn && conn.removeConversation(params);
    this.connections.delete(params.connection_id);
    if (conn === this.activeConversation) this.setActiveConversation(conn);
    this.update({connections: true});
  }

  setActiveConversation(params) {
    let activeConversation = !params.connection_id && !params.conversation_id && this.notifications;
    if (activeConversation) return this.update({activeConversation});

    activeConversation = this.findConversation(params);
    if (activeConversation) return this.update({activeConversation});

    // Need to expand params manually, in case we are passing in a reactive object
    const props = {...params, connection_id: params.connection_id || '', frozen: 'Not found.'};
    ['conversation_id', 'name'] .forEach(k => Object.hasOwn(params, k) && (props[k] = params[k]));
    return this.update({activeConversation: props.conversation_id ? new Conversation(props) : new Connection(props)});
  }

  update(params) {
    super.update(params);
    if (Object.hasOwn(params, 'unreadIncludePrivateMessages')) this._calculateUnreadDebounced();
    return this;
  }

  _calculateUnread(clear) {
    let [notifications, unread] = [0, 0];
    for (const connection of this.connections.toArray()) {
      for (const conversation of connection.conversations.toArray()) {
        if (clear) conversation.update({notifications: 0});
        notifications += conversation.is('private') ? (this.unreadIncludePrivateMessages ? conversation.unread : 0) : conversation.notifications;
        unread += conversation.is('private') ? 0 : conversation.notifications;
      }
    }

    if (clear) return;
    this.notifications.update({notifications, unread});
    this.update({notifications: true});
  }

  _dispatchMessage(msg) {
    msg.dispatchTo = camelCase('wsEvent_' + this._getEventNameFromMessage(msg));
    msg.silent = this.ignoreStatuses;
    this.emit(msg.dispatchTo, msg);

    const conn = this.findConversation({connection_id: msg.connection_id});
    if (!conn) return;
    if (conn[msg.dispatchTo]) conn[msg.dispatchTo](msg);
    if (!msg.bubbles) return;

    const conversation = conn.findConversation(msg);
    if (conversation && conversation[msg.dispatchTo]) {
      conversation[msg.dispatchTo](msg);
    }

    if (msg.highlight && !conversation.is('private')) {
      this.notifications.addMessages(msg);

      if (conversation === this.activeConversation && notify.appHasFocus) {
        conversation.markAsRead();
      }
      else {
        conversation.update({notifications: conversation.notifications + 1});
      }
    }
  }

  _getEventNameFromMessage(msg) {
    if (msg.errors) return 'error';
    if (msg.event === 'state') return msg.type;

    if (msg.event === 'sent' && msg.message.match(/\/\S+/)) {
      msg.command = msg.message.split(/\s+/).filter(s => s.length);
      msg.command[0] = msg.command[0].substring(1);
      return 'sent_' + msg.command[0].toLowerCase();
    }

    return msg.event;
  }

  _maybeUpgradeActiveConversation(conversation) {
    const active = this.activeConversation;
    if (!conversation.conversation_id) return conversation;
    if (conversation.connection_id && conversation.connection_id !== active.connection_id) return conversation;
    if (conversation.conversation_id && conversation.conversation_id !== active.conversation_id) return conversation;
    this.update({activeConversation: conversation});
    return conversation;
  }

  _onConnectionChange(socket) {
    if (socket.is('open') && this.is('pending')) return this.load();
    if (socket.is('closed')) {
      this.connections.forEach(conn => conn.update({state: 'unreachable'}));
      if (!this.is(['error', 'loading'])) this.update({status: 'pending'});
    }
  }
}
