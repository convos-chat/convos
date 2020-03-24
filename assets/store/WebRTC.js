import adapter from 'webrtc-adapter';
import Reactive from '../js/Reactive';
import WebRTCPeerConnection from './WebRTCPeerConnection';
import {clone, q} from '../js/util';
import {omnibus} from '../store/Omnibus';

/*
 * https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API
 * https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Protocols
 * https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Connectivity
 * https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Perfect_negotiation
 *
 * https://webrtc.github.io/test-pages/
 * https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
 * https://github.com/webrtc/test-pages/blob/63a46f73c917ffcdf765bd11622b10bf473eb11c/src/peer2peer/js/main.js
 *
 * https://meetrix.io/blog/webrtc/coturn/installation.html
 *
 * about:webrtc
 */
export default class WebRTC extends Reactive {
  constructor() {
    super();

    this.prop('rw', 'dialog', null);
    this.prop('rw', 'inCall', false);
    this.prop('rw', 'localStream', {id: ''});
    this.prop('rw', 'peerConfig', {});

    this.prop('persist', 'constraints', {audio: true, video: true});

    this.prop('rw', 'cameras', []);
    this.prop('rw', 'microphones', []);
    this.prop('rw', 'speakers', []);

    this.prop('rw', 'videoQuality', '640x360');
    this.prop('ro', 'videoQualityOptions', [
      ['Lo-def',   '320x180'],  // qVGA
      ['Standard', '640x360'],  // VGA
      ['HD',       '1280x720'], // HD
    ]);

    this.pc = {};
    this.unsubscribe = {};

    // Try to cleanup before we close the window
    this.call = this.call.bind(this);
    this.hangup = this.hangup.bind(this);
    window.addEventListener('beforeunload', this.hangup);
  }

  async call(dialog, constraints) {
    if (this.inCall) this.hangup();
    if (!constraints) constraints = this.constraints;

    if (this.unsubscribe.dialogRtc) this.unsubscribe.dialogRtc();
    this.unsubscribe.dialogRtc = dialog.on('rtc', msg => this._onSignal(msg));
    this.update({inCall: true, constraints, dialog});

    const localStream = await navigator.mediaDevices.getUserMedia(this.constraints);
    this.update({localStream});
    this._send('call', {});
    this._getDevices();
  }

  hangup() {
    if (!this.inCall) return;
    this._send('hangup', {});
    this._mapPc(pc => pc.hangup());
    if (this.localStream.getTracks) this.localStream.getTracks().forEach(track => track.stop());
    this.update({inCall: false, localStream: {id: ''}});
  }

  id(obj) {
    return String(obj && obj.id || obj || '').toLowerCase()
      .replace(/\W+$/, '').replace(/\W/g, '-').replace(/^[^a-z]+/i, 'uuid-');
  }

  isMuted(target, kind) {
    const stream = this.peerConnections({target}).map(pc => pc.remoteStream)[0] || this.localStream;
    const tracks = kind == 'audio' ? stream.getAudioTracks() : stream.getVideoTracks();
    return tracks.filter(track => track.enabled).length == tracks.length ? false : true;
  }

  mute(target, kind, mute) {
    const stream = this.peerConnections({target}).map(pc => pc.remoteStream)[0] || this.localStream;
    const tracks = kind == 'audio' ? stream.getAudioTracks() : stream.getVideoTracks();
    tracks.forEach(track => { track.enabled = mute === undefined ? !track.enabled : mute });
    this.emit('update', this, {});
  }

  peerConnections(filter) {
    return this._mapPc(pc => {
      if (filter.target) return pc.target == filter.target ? pc : false;
      if (filter.remoteStream) return pc.remoteStream ? pc : false;
      return pc;
    }).filter(Boolean);
  }

  async _getDevices() {
    const devices = {cameras: [], microphones: [], speakers: [], unknown: []};
    const enumerateDevices = await navigator.mediaDevices.enumerateDevices();

    enumerateDevices.forEach(dev => {
      const type = dev.kind == 'audioinput' ? 'microphones'
                 : dev.kind == 'audiooutput' ? 'speakers'
                 : dev.kind == 'videoinput' ? 'cameras'
                 : 'unknown';

      devices[type].push({id: dev.deviceId, type: dev.kind, name: dev.label || dev.text || dev.deviceId});
    });

    this.update(devices);
  }

  _mapPc(cb) {
    return Object.keys(this.pc).map(target => cb(this.pc[target]));
  }

  _normalizedPeerConfig() {
    const config = clone(this.peerConfig);
    config.iceServers = config.ice_servers || [];
    delete config.ice_servers;

    config.iceServers.forEach(s => {
      if (s.credential_type) s.credentialType = s.credential_type;
      delete s.credential_type;
    });

    return config;
  }

  _onSignal(msg) {
    if (msg.type == 'signal') return this._pc(msg).signal(msg);
    if (msg.type == 'call') return this._pc(msg).call(msg);
    if (msg.type == 'hangup') return this._pc(msg).hangup(msg);
  }

  _pc(msg) {
    const target = msg.from;

    // Clean up old connections
    if (this.pc[target] && ['call', 'hangup'].indexOf(msg.type) != -1) {
      this.pc[target].hangup();
      delete this.pc[target];
    }

    // Return current connection
    if (this.pc[target]) return this.pc[target];

    const peerConfig = this._normalizedPeerConfig(this.peerConfig);
    const pc = new WebRTCPeerConnection({localStream: this.localStream, target, peerConfig});
    pc.on('hangup', () => delete this.pc[target]);
    pc.on('signal', msg => this._send('signal', msg));
    pc.on('update', () => this.emit('update', this, {}));
    return (this.pc[target] = pc);
  }

  _send(event, msg) {
    if (this.dialog) this.dialog.send({...msg, method: 'rtc', event});
  }
}
