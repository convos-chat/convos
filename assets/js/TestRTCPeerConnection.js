export default class TestRTCPeerConnection {
  constructor(params) {
    this.params = params;
    this.signalingState = '';
    this.tracks = [];
  }

  addTrack(track) {
    this.tracks.push(track);
  }

  close() {
    this.tracks = [];
  }

  async createAnswer() {
    return {sdp: 'v=1\r\n'};
  }

  async createOffer() {
    return {sdp: 'v=0\r\n'};
  }

  getStats() {
    return new Set();
  }

  setLocalDescription(sdp) {
    this.localSdp = sdp;
  }

  setRemoteDescription(sdp) {
    this.remoteSdp = sdp;
  }
}
