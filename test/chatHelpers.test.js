import Conversation from '../assets/store/Conversation';
import Time from '../assets/js/Time';
import {conversationUrl, onInfinityVisibility} from '../assets/js/chatHelpers';
import {expect, test} from 'vitest';

window.open = (url, name) => {
  const w = {opened: true, events: {}, name, url};
  w.close = () => (w.opened = false);
  w.addEventListener = (name, cb) => (w.events[name] = cb);
  return w;
};

test('onInfinityVisibility - load enough messages', () => {
  const conversation = new Conversation({connection_id: 'irc-foo', conversation_id: '#convos'});

  conversation.update({status: 'success'});
  conversation.loaded = [];
  conversation.load = (params) => { conversation.loaded.push(params); return conversation };

  test('no messages', () => {
    onInfinityVisibility({detail: {infinityEl: {offsetHeight: 900, scrollHeight: 899}}}, {conversation});
    expect(conversation.loaded).toEqual([]);
  });

  test('load more', () => {
    conversation.messages.push([{message: 'whatever', ts: '2021-02-11T03:04:05.000Z'}]);
    onInfinityVisibility({detail: {infinityEl: {offsetHeight: 900, scrollHeight: 900}}}, {conversation});
    expect(conversation.loaded).toEqual([{before: '2021-02-11T03:04:05.000Z'}]);
  });

  test('has enough', () => {
    onInfinityVisibility({detail: {infinityEl: {offsetHeight: 900, scrollHeight: 901}}}, {conversation});
    expect(conversation.loaded).toEqual([{before: '2021-02-11T03:04:05.000Z'}]);
  });
});

test('conversationUrl', () => {
  test('conversationUrl', () => {
    const ts = new Time('1983-02-24T05:06:07Z');
    expect(conversationUrl({connection_id: 'irc-foo', ts})).toBe('/chat/irc-foo#1983-02-24T05:06:07.000Z');
    expect(conversationUrl({connection_id: 'irc-foo', conversation_id: '#convos', ts})).toBe('/chat/irc-foo/%23convos#1983-02-24T05:06:07.000Z');
  });
});
