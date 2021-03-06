import Conversation from '../assets/store/Conversation';
import Time from '../assets/js/Time';
import User from '../assets/store/User';
import {get} from 'svelte/store';
import {chatHelper, videoWindow, conversationUrl} from '../assets/js/chatHelpers';
import {generateWriteable} from '../assets/store/writable';

window.open = (url, name) => {
  const w = {opened: true, events: {}, name, url};
  w.close = () => (w.opened = false);
  w.addEventListener = (name, cb) => (w.events[name] = cb);
  return w;
};

describe('onInfinityVisibility - load enough messages', () => {
  const conversation = new Conversation({connection_id: 'irc-foo', conversation_id: '#convos'});
  const onInfinityVisibility = chatHelper('onInfinityVisibility', {conversation, onLoadHash: ''});

  conversation.update({status: 'success'});
  conversation.loaded = [];
  conversation.load = (params) => { conversation.loaded.push(params); return conversation };

  test('no messages', () => {
    onInfinityVisibility({detail: {infinityEl: {offsetHeight: 900, scrollHeight: 899}}});
    expect(conversation.loaded).toEqual([]);
  });

  test('load more', () => {
    conversation.messages.push([{message: 'whatever', ts: '2021-02-11T03:04:05.000Z'}]);
    onInfinityVisibility({detail: {infinityEl: {offsetHeight: 900, scrollHeight: 900}}});
    expect(conversation.loaded).toEqual([{before: '2021-02-11T03:04:05.000Z'}]);
  });

  test('has enough', () => {
    onInfinityVisibility({detail: {infinityEl: {offsetHeight: 900, scrollHeight: 901}}});
    expect(conversation.loaded).toEqual([{before: '2021-02-11T03:04:05.000Z'}]);
  });
});

describe('onMessageClick', () => {
  const conversation = new Conversation({});
  const popoverTarget = generateWriteable('chat:popoverTarget');
  const user = new User({videoService: 'https://meet.convos.chat'});
  const onMessageClick = chatHelper('onMessageClick', {conversation, popoverTarget, user});

  conversation.send = (message) => (conversation.sent = message);

  test('default click', () => {
    const e = {target: document.createElement('a')};
    onMessageClick(e);
    expect(e.target.target).toBe('');
  });

  test('inside embed', () => {
    const e = {target: document.createElement('a')};
    const embedEl = document.createElement('div');
    embedEl.className = 'embed';
    embedEl.appendChild(e.target);
    onMessageClick(e);
    expect(e.target.target).toBe('_blank');
  });

  test('inside le-meta', () => {
    const e = {target: document.createElement('span')};

    const metaEl = document.createElement('div');
    metaEl.className = 'le-meta';
    metaEl.appendChild(e.target);

    const embedEl = document.createElement('div');
    embedEl.className = 'embed';
    embedEl.appendChild(metaEl);

    onMessageClick(e);
    expect(embedEl.className).toBe('embed is-expanded');
  });

  test('action details', () => {
    let preventDefault = 0;
    const e = {preventDefault: () => (++preventDefault), target: document.createElement('a')};
    e.target.href = '#action:details:0';
    conversation.messages.push([{showDetails: false}]);
    onMessageClick(e);
    expect(conversation.messages.get(0).showDetails).toBe(true);

    onMessageClick(e);
    expect(preventDefault).toBe(2);
    expect(conversation.messages.get(0).showDetails).toBe(false);
  });

  test('action join', () => {
    let preventDefault = 0;
    const e = {preventDefault: () => (++preventDefault), target: document.createElement('a')};
    e.target.href = '#action:join:foo-bÅ_';
    onMessageClick(e);
    expect(preventDefault).toBe(1);
    expect(conversation.sent).toBe('/join foo-bÅ_');
  });

  test('fullscreen', () => {
    let preventDefault = 0;
    const e = {preventDefault: () => (++preventDefault), target: document.createElement('img')};

    e.target.src = 'image.jpeg';
    expect(document.querySelector('.fullscreen')).toBeFalsy();
    onMessageClick(e);
    expect(preventDefault).toBe(1);
    expect(document.querySelector('.fullscreen')).toBeTruthy();
    expect(document.querySelector('.fullscreen img[src="image.jpeg"]')).toBeTruthy();
  });

  test('videolink', () => {
    let preventDefault = 0;
    const e = {preventDefault: () => (++preventDefault), target: document.createElement('a')};
    e.target.href = 'https://demo.convos.chat/video/meet.convos.chat/whatever';

    // Do nothing
    onMessageClick(e);
    expect(preventDefault).toBe(0);

    // Proxy to another link
    const realLink = document.createElement('a');
    realLink.href = 'https://demo.convos.chat/video/meet.convos.chat/whatever';
    realLink.target = 'convos_video';
    document.body.appendChild(realLink);
    onMessageClick(e);
    expect(preventDefault).toBe(1);
    expect(get(videoWindow).url).toEqual('/video/meet.convos.chat/whatever?nick=');

    // Clean up before next test
    videoWindow.close();
  });
});

describe('onVideoLinkClick', () => {
  const conversation = new Conversation({connection_id: 'irc-foo', conversation_id: '#convos'});
  const user = new User({videoService: 'https://meet.convos.chat'});
  const onVideoLinkClick = chatHelper('onVideoLinkClick', {conversation, user});

  let preventDefault = 0;
  const e = {preventDefault: () => (++preventDefault), target: document.createElement('a')};
  e.target.href = '#action:video';

  let w1;
  test('open video window', () => {
    conversation.participants.add({nick: 'super_duper', me: true});
    onVideoLinkClick(e);
    w1 = get(videoWindow);
    expect(preventDefault).toBe(1);
    expect([w1.url, w1.name]).toEqual(['/video/meet.convos.chat/%23convos%20-%20foo?nick=super_duper', 'convos_video']);
    expect(w1.opened).toBe(true);
  });

  test('close video window after open', () => {
    onVideoLinkClick(e);
    expect(preventDefault).toBe(2);
    expect(w1.opened).toBe(false);
  });

  test('close window from outside', () => {
    onVideoLinkClick(e);
    const w2 = get(videoWindow);
    expect(preventDefault).toBe(3);
    expect(w2).not.toBe(w1);
    expect(w2.opened).toBe(true);
    ['beforeunload', 'close'].forEach(name => w2.events[name]());
    expect(get(videoWindow)).toBe(null);
  });

  test('internal video link', () => {
    conversation.participants.rename('super_duper', 'superman')
    e.target.href = '/whatever/video/meet.convos.chat/%23convos%20-%20foo?nick=superwoman';
    onVideoLinkClick(e);
    expect(preventDefault).toBe(4);
    expect(get(videoWindow).url).toBe('/video/meet.convos.chat/%23convos%20-%20foo?nick=superman');
  });

  test('external link', () => {
    e.target.className = 'le-provider-jitsi';
    e.target.href = 'https://meet2.convos.chat/cool-beans';
    onVideoLinkClick(e);
    expect(preventDefault).toBe(5);
    expect(get(videoWindow).url).toBe('/video/meet2.convos.chat/cool-beans?nick=superman');
  });
});

describe('conversationUrl', () => {
  test('conversationUrl', () => {
    const ts = new Time('1983-02-24T05:06:07Z');
    expect(conversationUrl({connection_id: 'irc-foo', ts})).toBe('/chat/irc-foo#1983-02-24T05:06:07.000Z');
    expect(conversationUrl({connection_id: 'irc-foo', conversation_id: '#convos', ts})).toBe('/chat/irc-foo/%23convos#1983-02-24T05:06:07.000Z');
  });
});
