import adapter from 'webrtc-adapter';
import Reactive from '../js/Reactive';
import WebRTCPeerConnection from './WebRTCPeerConnection';
import {clone, q, showEl} from '../js/util';
import {viewport} from './Viewport';

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
  constructor(params) {
    super();

    this.prop('ro', 'enabled', () => !!(this.peerConfig.ice_servers || []).length);

    this.prop('rw', 'conversation', null);
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

    this.connections = {};
    this.unsubscribe = {};

    // Try to cleanup before we close the window
    this.call = this.call.bind(this);
    this.hangup = this.hangup.bind(this);
    window.addEventListener('beforeunload', this.hangup);
  }

  async call(conversation, constraints) {
    if (this.localStream.id) await this.hangup();
    if (!constraints) constraints = this.constraints;

    this.unsubscribe.conversationRtc = conversation.on('rtc', msg => this._onSignal(msg));
    this.update({constraints, conversation});

    const localStream = await navigator.mediaDevices.getUserMedia(constraints);
    this.update({localStream});
    this._send('call', {});
    this._getDevices();
  }

  async hangup() {
    if (!this.localStream.id) return;
    this._send('hangup', {});
    this._mapPc(pc => pc.hangup());
    if (this.localStream.getTracks) this.localStream.getTracks().forEach(track => track.stop());
    if (this.unsubscribe.conversationRtc) this.unsubscribe.conversationRtc();
    this.update({localStream: {id: ''}});
  }

  id(obj) {
    const id = String(obj && obj.id || obj || '').toLowerCase().replace(/\W/g, '-');
    return id ? 'uuid-' + id : '';
  }

  isMuted(target, kind = 'audio') {
    const stream = this.peerConnections({target}).map(pc => pc.remoteStream)[0] || this.localStream;
    if (!stream.id) return true;

    const tracks = kind == 'audio' ? stream.getAudioTracks() : stream.getVideoTracks();
    if (!tracks.length) return true;

    return tracks.filter(track => track.enabled).length == tracks.length ? false : true;
  }

  mute(target, kind, mute) {
    const stream = this.peerConnections({target}).map(pc => pc.remoteStream)[0] || this.localStream;
    const tracks = kind == 'audio' ? stream.getAudioTracks() : stream.getVideoTracks();
    tracks.forEach(track => { track.enabled = mute === undefined ? !track.enabled : !mute });
    this.emit('update', this, {});
  }

  peerConnections(filter) {
    return this._mapPc(pc => {
      if (filter.target) return pc.target == filter.target ? pc : false;
      if (filter.remoteStream) return pc.remoteStream ? pc : false;
      return pc;
    }).filter(Boolean);
  }

  render() {
    this._renderRtcConversation(this.id(this.localStream), this.localStream);

    this.peerConnections({remoteStream: true}).forEach(pc => {
      this._renderRtcConversation(this.id(pc), pc.remoteStream);
    });

    if (!this.localStream.id) {
      q(document, '.fullscreen-wrapper [data-rtc-id]', () => viewport.showFullscreen(null));
    }
  }

  _connection(msg) {
    const target = msg.from;

    // Clean up old connections
    if (this.connections[target] && ['call', 'hangup'].indexOf(msg.type) != -1) {
      this.connections[target].hangup();
      delete this.connections[target];
    }

    // Return existing connection
    if (this.connections[target]) return this.connections[target];

    // Create connection
    const peerConfig = this._normalizedPeerConfig(this.peerConfig);
    const pc = new WebRTCPeerConnection({localStream: this.localStream, target, peerConfig});
    pc.on('hangup', () => delete this.connections[target]);
    pc.on('signal', msg => this._send('signal', msg));
    pc.on('update', () => this.emit('update', this, {}));
    this.emit('connection', (this.connections[target] = pc));
    return pc;
  }

  _ensureEventListenersOnButtons(parentEl) {
    if (parentEl._addEventListenersToButtonsDone) return;
    parentEl._addEventListenersToButtonsDone = true;
    q(parentEl, '.rtc-conversation__name', ['click', (e) => this._toggleInfo(e)]);
    q(parentEl, '.rtc-conversation__hangup', ['click', (e) => this.hangup()]);
    q(parentEl, '.rtc-conversation__zoom', ['click', (e) => this._toggleZoomed(e)]);
    q(parentEl, '.rtc-conversation__mute-audio', ['click', (e) => this._toggleMuted(e, 'audio')]);
    q(parentEl, '.rtc-conversation__mute-video', ['click', (e) => this._toggleMuted(e, 'video')]);
  }

  async _getDevices() {
    const devices = {cameras: [], microphones: [], speakers: [], unknown: []};
    const enumerateDevices = await navigator.mediaDevices.enumerateDevices();

    enumerateDevices.forEach(dev => {
      const type = dev.kind == 'audioinput' ? 'microphones'
                 : dev.kind == 'audiooutput' ? 'speakers'
                 : dev.kind == 'videoinput' ? 'cameras'
                 : 'unknown';

      devices[type].push({id: dev.deviceId, name: dev.label || dev.text || dev.deviceId});
    });

    this.update(devices);
  }

  _mapPc(cb) {
    return Object.keys(this.connections).map(target => cb(this.connections[target]));
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
    if (msg.type == 'signal') return this._connection(msg).signal(msg);
    if (msg.type == 'call') return this._connection(msg).call(msg);
    if (msg.type == 'hangup') return this._connection(msg).hangup(msg);
  }

  _renderRtcConversation(id, stream) {
    q(document, '[data-rtc-id="' + (id || 'uuid-missing') + '"]', conversationEl => {
      const hasVideo = this.constraints.video;
      conversationEl.classList[hasVideo ? 'remove' : 'add']('has-audio-only');
      conversationEl.classList[hasVideo ? 'add' : 'remove']('has-video');
      this._renderVideoEl(conversationEl.querySelector('video'), stream);
      this._ensureEventListenersOnButtons(conversationEl);
    });
  }

  _renderVideoEl(videoEl, stream) {
    videoEl.width = parseInt(this.videoQuality.split('x')[0], 10);
    videoEl.height = parseInt(this.videoQuality.split('x')[1], 10);
    if (videoEl.srcObject == stream) return;
    if (stream == this.localStream) [videoEl.muted, videoEl.volume] = [true, 0];
    videoEl.setAttribute('autoplay', '');
    videoEl.setAttribute('playsinline', '');
    videoEl.oncanplay = () => { videoEl.parentNode.className = videoEl.parentNode.className.replace(/has-state-\d+/, 'has-state-' + videoEl.readyState) };
    videoEl.srcObject = videoEl.classList.contains('is-disabled') ? null : stream;
  }

  _send(event, msg) {
    if (this.conversation) this.conversation.send({...msg, method: 'rtc', event});
  }

  _toggleInfo(e) {
    e.preventDefault();
    const infoEl = q(e.target.closest('[data-rtc-id]'), '.rtc-conversation__info')[0];
    if (infoEl) showEl(infoEl, 'toggle');
  }

  _toggleMuted(e, kind) {
    const id = e.target.closest('[data-rtc-id]').dataset.rtcId;
    e.preventDefault();
    this.mute(id, kind);
    const classListMethod = this.isMuted(id, kind) ? 'add' : 'remove';
    const btnSel = '[data-rtc-id="' + id + '"] .rtc-conversation__mute-' + kind;
    q(document, btnSel, el => el.classList[classListMethod]('is-active'));
  }

  _toggleZoomed(e) {
    e.preventDefault();

    const btn = e.target.closest('.btn');
    const minimize = btn.classList.contains('is-active');
    const conversationEl = btn.closest('[data-rtc-id]');
    const btnSel = '[data-rtc-id="' + conversationEl.dataset.rtcId + '"] .rtc-conversation__zoom';
    q(document, btnSel, el => el.classList[minimize ? 'remove' : 'add']('is-active'));

    if (minimize) {
      q(document, '.fullscreen-wrapper [data-rtc-id]', () => viewport.showFullscreen(null));
      return;
    }

    const mediaWrapper = viewport.showFullscreen(conversationEl);
    const conversationFocus = mediaWrapper.querySelector('[data-rtc-id]');
    conversationFocus.classList.add('has-focus');
    conversationFocus.classList.remove('is-local');

    const conversationLocal = conversationEl.parentNode.querySelector('.rtc-conversation.is-local').cloneNode(true);
    mediaWrapper.appendChild(conversationLocal);

    // Do not render the small video previews
    q(conversationEl.parentNode, 'video', el => el.classList.add('is-disabled'));

    // Allow to go back to small video preview
    viewport.on('hidemediawrapper').then(() => {
      q(conversationEl.parentNode, 'video', el => el.classList.remove('is-disabled'));
      this.render();
    });

    this.render();
  }
}
