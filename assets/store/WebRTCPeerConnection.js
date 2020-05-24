import Reactive from '../js/Reactive';

export default class WebRTCPeerConnection extends Reactive {
  constructor(params) {
    super(params);

    this.prop('ro', 'localStream', params.localStream);
    this.prop('ro', 'peerConfig', params.peerConfig);
    this.prop('ro', 'target', params.target);
    this.prop('rw', 'info', this._infoTemplate());
    this.prop('rw', 'remoteStream', null);
    this.prop('rw', 'role', '');

    this.signalQueue = [];
  }

  async call() {
    this._throwifStarted();
    this.update({role: 'caller'});
    const pc = this._pc();
    const sdp = await pc.createOffer();
    pc.setLocalDescription(sdp);
    this.emit('signal', {offer: sdp.sdp, target: this.target});
    this._processSignalQueue();
  }

  hangup() {
    if (this.pc) this.pc.close();
    this.update({role: ''});
    this.emit('hangup');
  }

  async refreshInfo() {
    const stats = this.pc ? Array.from((await this.pc.getStats()).values()) : [];
    const info = this._infoTemplate();

    stats.forEach(item => {
      if (item.type == 'local-candidate') {
        info.localAddress = item.address || '';
      }
      else if (item.type == 'remote-candidate') {
        info.remoteAddress = item.address || '';
      }
      else if (item.type == 'candidate-pair') {
        info.bytesReceived = item.bytesReceived;
        info.bytesSent = item.bytesSent;
      }
      else if (item.type == 'inbound-rtp') {
        const type = item.kind || item.mediaType || 'unknown';
        ['bitrateMean', 'discardedPackets', 'framerateMean', 'framesDecoded', 'jitter', 'nackCount', 'packetsLost', 'packetsReceived']
          .forEach(k => { info[type].inbound[k] = item[k] || 0 });
      }
      else if (item.type == 'outbound-rtp') {
        const type = item.kind || item.mediaType || 'unknown';
        ['bitrateMean', 'droppedFrames', 'framerateMean', 'framesEncoded', 'nackCount', 'packetsSent']
          .forEach(k => { info[type].outbound[k] = item[k] || 0 });
      }
    });

    return this.update({info});
  }

  signal(msg) {
    const queueMethod = msg.offer ? 'unshift' : 'push'; // process "SDP offer" before "ice candidate"
    this.signalQueue[queueMethod](msg);
    this._processSignalQueue();
  }

  _infoTemplate() {
    return {
      bytesReceived: 0,
      bytesSent: 0,
      iceConnectionState: this.pc && this.pc.iceConnectionState || '',
      iceGatheringState: this.pc && this.pc.iceGatheringState || '',
      localAddress: '',
      remoteAddress: '',
      signalingState: this.pc && this.pc.signalingState || '',
      audio: {inbound: {}, outbound: {}},
      video: {inbound: {}, outbound: {}},
    };
  }

  _onIceCandidate({candidate}) {
    if (!candidate) return;
    this.emit('signal', {ice: candidate.candidate, sdpMid: candidate.sdpMid, sdpMLineIndex: candidate.sdpMLineIndex, target: this.target});
  }

  _onTrack({streams, track}) {
    track.onended = (e) => this.refreshInfo();
    track.onmute = (e) => this.refreshInfo();
    track.onunmute = (e) => this.refreshInfo();
    this.update({remoteStream: streams[0] || null});
  }

  _pc() {
    if (this.pc) return this.pc;

    const pc = new RTCPeerConnection(this.peerConfig);
    this.localStream.getTracks().forEach(track => pc.addTrack(track, this.localStream));
    pc.onicecandidate = (e) => this._onIceCandidate(e);
    pc.oniceconnectionstatechange = (e) => this.refreshInfo();
    pc.onicegatheringstatechange = (e) => this.refreshInfo();
    pc.onremovetrack = (e) => this.refreshInfo();
    pc.onsignalingstatechange = (e) => this.refreshInfo();
    pc.ontrack = (e) => this._onTrack(e);

    return (this.pc = pc);
  }

  _processSignalQueue() {
    this.signalQueue = this.signalQueue.filter((msg, i) => {
      if (msg.ice) return this._processIceSignalIceCandiate(msg) ? false : true;
      if (msg.answer) return this._processSignalAnswer(msg) ? false : true;
      if (msg.offer) return this._processSignalOffer(msg) ? false : true;
      return false;
    });

    this.signalQueue = [];
  }

  _processSignalAnswer(msg) {
    const pc = this._pc();
    if (pc.signalingState != 'have-local-offer') {
      console.error('[processSignalAnswer] signalingState =', pc.signalingState);
      return false;
    }

    pc.setRemoteDescription(new RTCSessionDescription({sdp: msg.answer, type: 'answer'}));
    return true;
  }

  _processIceSignalIceCandiate(msg) {
    this._pc().addIceCandidate(new RTCIceCandidate({candidate: msg.ice, sdpMid: msg.sdpMid, sdpMLineIndex: msg.sdpMLineIndex}));
    return true;
  }

  _processSignalOffer(msg) {
    this._throwifStarted();
    this.update({role: 'callee'});

    const pc = this._pc();
    if (pc.signalingState != 'stable') {
      console.error('[processSignalOffer] signalingState =', pc.signalingState);
      return false;
    }

    pc.setRemoteDescription(new RTCSessionDescription({sdp: msg.offer, type: 'offer'}));
    pc.createAnswer().then(sdp => {
      pc.setLocalDescription(sdp);
      this.emit('signal', {answer: sdp.sdp, target: this.target});
    });

    return true;
  }

  _throwifStarted() {
    if (this.role) throw '[WebRTCPeerConnection] Already started ' + this.target + ' as ' + this.role;
  }
}
