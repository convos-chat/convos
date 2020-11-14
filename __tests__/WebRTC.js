import Conversation from '../assets/store/Conversation';
import WebRTC from '../assets/store/WebRTC';
import TestMediaDevices from '../assets/js/TestMediaDevices';
import TestRTCPeerConnection from '../assets/js/TestRTCPeerConnection';

global.navigator.mediaDevices = TestMediaDevices;
global.RTCPeerConnection = TestRTCPeerConnection;

test('constructor', () => {
  const webrtc = new WebRTC({});
  expect(webrtc.enabled).toBe(false);
  expect(webrtc.localStream.id).toBeFalsy()
  expect(webrtc.localStream).toEqual({id: ''});
  expect(webrtc.constraints).toEqual({audio: true, video: true});
  expect(webrtc.videoQuality).toBe('640x360');
});

test('id', () => {
  const webrtc = new WebRTC({});
  expect(webrtc.id({id: '42'})).toBe('uuid-42');
  expect(webrtc.id('..42  ')).toBe('uuid---42--');
  expect(webrtc.id()).toBe('');
});

test('mute', async () => {
  const conversation = mockedConversation();
  const webrtc = new WebRTC({});
  expect(webrtc.isMuted()).toBe(true);

  await webrtc.call(conversation);
  expect(webrtc.isMuted()).toBe(true);

  const audioTracks = [{enabled: false}];
  const videoTracks = [{enabled: true}];
  webrtc.localStream.getAudioTracks = () => audioTracks;
  webrtc.localStream.getVideoTracks = () => videoTracks;

  expect(webrtc.isMuted('local', 'audio')).toBe(true);
  expect(webrtc.isMuted('local', 'video')).toBe(false);

  webrtc.mute('local', 'audio');
  expect(webrtc.isMuted('local', 'audio')).toBe(false);

  webrtc.mute('local', 'video', true);
  expect(webrtc.isMuted('local', 'video')).toBe(true);

  webrtc.mute('local', 'video', false);
  expect(webrtc.isMuted('local', 'video')).toBe(false);
});

test('call', async () => {
  const conversation = mockedConversation();
  const webrtc = new WebRTC({});

  await webrtc.call(conversation);
  expect(webrtc.localStream.id).toBeTruthy();
  expect(webrtc.constraints).toEqual(webrtc.localStream.constraints);
  expect(webrtc.conversation.name).toBe(conversation.name);

  expect(webrtc.cameras).toEqual([{id: 2, name: 'Cam1'}]);
  expect(webrtc.microphones).toEqual([{id: 1, name: 'Mic1'}]);
  expect(webrtc.speakers).toEqual([{id: 3, name: 'Speaker1'}]);
});

test('hangup', async () => {
  const conversation = mockedConversation();
  const webrtc = new WebRTC({});

  await webrtc.hangup(); // noop
  await webrtc.call(conversation);
  expect(webrtc.localStream.id).toBeTruthy();

  conversation.emit('rtc', {type: 'call', from: 'superwoman'});
  expect(getConn(webrtc, 'superwoman').localStream).toBe(webrtc.localStream);
  expect(getConn(webrtc, 'superwoman').role).toBe('caller');
  expect(getConn(webrtc, 'superwoman').target).toBe('superwoman');

  conversation.emit('rtc', {type: 'call', from: 'superman'});
  expect(getConn(webrtc, 'superman').localStream).toBe(webrtc.localStream);
  expect(getConn(webrtc, 'superman').target).toBe('superman');

  let conn = getConn(webrtc, 'superwoman');
  conversation.emit('rtc', {type: 'call', from: 'superwoman'});
  expect(getConn(webrtc, 'superwoman').localStream).toBe(webrtc.localStream);
  expect(getConn(webrtc, 'superwoman').target).toBe('superwoman');
  expect(getConn(webrtc, 'superwoman').id).not.toBe(conn.id);
  expect(conn.role).toBe('');

  const tracks = webrtc.localStream.getTracks();
  expect(tracks[0].stopped).toBe(undefined);

  await webrtc.hangup();
  expect(webrtc.localStream.id).toBeFalsy()
  expect(tracks[0].stopped).toBe(true);

  // Does nothing after hangup
  conversation.emit('rtc', {type: 'call', from: 'superwoman'});
  expect(webrtc.peerConnections({})).toEqual([]);
});

test('peerConfig', async () => {
  const peerConfig = {
    bundlePolicy: 'balanced',
    iceTransportPolicy: 'all',
    rtcpMuxPolicy: 'require',
    ice_servers: [
      {credential: 'k1', credential_type: 'password', urls: 'stun:stun.example.com:3478', username: 's1'},
      {credential: 'k2', credential_type: 'password', urls: 'turn:turn.example.com:3478', username: 't2'},
    ],
  };

  const conversation = mockedConversation();
  const webrtc = new WebRTC({});
  webrtc.update({peerConfig});
  expect(webrtc.enabled).toBe(true);

  await webrtc.call(conversation);
  conversation.emit('rtc', {type: 'call', from: 'superwoman'});
  expect(getConn(webrtc, 'superwoman').peerConfig).toEqual({
    bundlePolicy: 'balanced',
    iceTransportPolicy: 'all',
    rtcpMuxPolicy: 'require',
    iceServers: [
      {credential: 'k1', credentialType: 'password', urls: 'stun:stun.example.com:3478', username: 's1'},
      {credential: 'k2', credentialType: 'password', urls: 'turn:turn.example.com:3478', username: 't2'},
    ],
  });
});

// test('signal', async () => {
//   const conversation = mockedConversation();
//   const webrtc = new WebRTC({});
// 
//   await webrtc.call(conversation);
// 
//   const pc = await webrtc.on('pc');
// });

function getConn(webrtc, target) {
  return webrtc.peerConnections({target})[0];
}

function mockedConversation() {
  const conversation = new Conversation({api: {operation() { return false }}, name: '#dummy'});

  conversation.send = (msg) => {
    if (msg.event == 'call') return setTimeout(() => conversation.emit('rtc', {from: 'superwoman', type: 'call'}));
  };

  return conversation;
}
