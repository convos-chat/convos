import {uuidv4} from './util';

const TestMediaDevices = {
  _localStreamId: 0,
  async getUserMedia(constraints) {
    const tracks = [{stop() { tracks[0].stopped = true }}];
    return {
      id: uuidv4().replace(/.$/, String(++navigator.mediaDevices._localStreamId)),
      constraints,
      getTracks() { return tracks },
      getAudioTracks() { return [] },
      getVideoTracks() { return [] },
    };
  },
  async enumerateDevices() {
    return [
      {kind: 'audioinput', deviceId: 1, label: 'Mic1'},
      {kind: 'videoinput', deviceId: 2, text: 'Cam1'},
      {kind: 'audiooutput', deviceId: 3, label: 'Speaker1'},
    ];
  },
}

export default TestMediaDevices;
