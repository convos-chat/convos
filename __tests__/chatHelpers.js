import Conversation from '../assets/store/Conversation';
import Time from '../assets/js/Time';
import User from '../assets/store/User';
import {get} from 'svelte/store';
import {chatHelper, videoWindow, urlToMessage} from '../assets/js/chatHelpers';

window.open = (url, name) => {
  const w = {opened: true, events: {}, name, url};
  w.close = () => (w.opened = false);
  w.addEventListener = (name, cb) => (w.events[name] = cb);
  return w;
};

test('onMessageClick', () => {
  const onVideoLinkClick = () => {};
  const onMessageClick = chatHelper('onMessageClick', {messages, onVideoLinkClick});
});

test('onVideoLinkClick', () => {
  const conversation = new Conversation({connection_id: 'irc-foo', conversation_id: '#convos'});
  const user = new User({videoService: 'https://meet.convos.chat'});
  const onVideoLinkClick = chatHelper('onVideoLinkClick', {conversation, user});

  let preventDefault = 0;
  const e = {preventDefault: () => (++preventDefault), target: document.createElement('a')};
  e.target.href = '#action:video';

  // Open video window
  conversation.participants.add({nick: 'super_duper', me: true});
  onVideoLinkClick(e);
  const w1 = get(videoWindow);
  expect(preventDefault).toBe(1);
  expect([w1.url, w1.name]).toEqual(['/video/meet.convos.chat/%23convos%20-%20foo?nick=super_duper', 'convos_video']);
  expect(w1.opened).toBe(true);

  // Close video window after open
  onVideoLinkClick(e);
  expect(preventDefault).toBe(2);
  expect(w1.opened).toBe(false);

  // Close window from outside
  onVideoLinkClick(e);
  const w2 = get(videoWindow);
  expect(preventDefault).toBe(3);
  expect(w2).not.toBe(w1);
  expect(w2.opened).toBe(true);
  ['beforeunload', 'close'].forEach(name => w2.events[name]());
  expect(get(videoWindow)).toBe(null);

  // Internal video link
  conversation.participants.rename('super_duper', 'superman')
  e.target.href = '/whatever/video/meet.convos.chat/%23convos%20-%20foo?nick=superwoman';
  onVideoLinkClick(e);
  expect(preventDefault).toBe(4);
  expect(get(videoWindow).url).toBe('/video/meet.convos.chat/%23convos%20-%20foo?nick=superman');

  // External link
  e.target.className = 'le-provider-jitsi';
  e.target.href = 'https://meet2.convos.chat/cool-beans';
  onVideoLinkClick(e);
  expect(preventDefault).toBe(5);
  expect(get(videoWindow).url).toBe('/video/meet2.convos.chat/cool-beans?nick=superman');
});

test('urlToMessage', () => {
  const ts = new Time('1983-02-24T05:06:07Z');
  expect(urlToMessage({connection_id: 'irc-foo', ts})).toBe('/chat/irc-foo#1983-02-24T05:06:07.000Z');
  expect(urlToMessage({connection_id: 'irc-foo', conversation_id: '#convos', ts})).toBe('/chat/irc-foo/%23convos#1983-02-24T05:06:07.000Z');
});
