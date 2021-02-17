import Reactive from './Reactive';
import {loadScript, removeChildNodes} from './util';

export default class Jitsi extends Reactive {
  constructor(params) {
    super();
    this.prop('ro', 'domain', params.domain || 'meet.jit.si');
    this.prop('ro', 'email', params.email || '');
    this.prop('rw', 'nick', params.nick || '');
    this.prop('rw', 'roomName', params.roomName || 'convos-default');

    this.prop('persist', 'disableAudioLevels', true, {key: 'video:disableAudioLevels'});
    this.prop('persist', 'disableH264', true, {key: 'video:disableH264'});
    this.prop('persist', 'resolution', 720, {key: 'video:resolution'});
  }

  async render(el) {
    this.targetEl = el;
    await loadScript('https://' + this.domain + '/external_api.js');
    removeChildNodes(this.targetEl);
    this.jitsi = new JitsiMeetExternalAPI(this.domain, this._options());

    document.addEventListener('keydown', (e) => {
      if (e.code == 'KeyC') this.jitsi.executeCommand('toggleChat');
      if (e.code == 'KeyD') this.jitsi.executeCommand('toggleShareScreen');
      if (e.code == 'KeyF') this.jitsi.executeCommand('toggleFilmStrip');
      if (e.code == 'KeyM') this.jitsi.executeCommand('toggleAudio');
      if (e.code == 'KeyR') this.jitsi.executeCommand('toggleRaiseHand');
      if (e.code == 'KeyV') this.jitsi.executeCommand('toggleVideo');
      if (e.code == 'KeyW') this.jitsi.executeCommand('toggleTileView');
      if (e.code == 'Space') this.jitsi.isAudioMuted().then(muted => muted && this.jitsi.executeCommand('toggleAudio'));
    });

    document.addEventListener('keyup', (e) => {
      if (e.code == 'Space') this.jitsi.isAudioMuted().then(muted => muted || this.jitsi.executeCommand('toggleAudio'));
    });
  }

  _configOverwrite() {
    return {
      disableAudioLevels: this.disableAudioLevels,
      disableH264: this.disableH264,
      enableWelcomePage: this.nick ? false : true,
      prejoinPageEnabled: this.nick ? false : true,
      minParticipants: 1,
      resolution: this.resolution,
      analytics: {
        googleAnalyticsTrackingId: '',
        scriptURLs: [],
      },
      e2eping: {
        analyticsInterval: -1,
        pingInterval: -1,
      },
    };
  }

  _interfaceConfigOverwrite() {
    const style = window.getComputedStyle(document.querySelector('.cms-navbar--wrapper'));
    const DEFAULT_BACKGROUND = style.backgroundColor || '#222222';

    const TOOLBAR_BUTTONS = [
      'camera',     'chat',               'closedcaptions',  'desktop',
      'etherpad',   'fodeviceselection',  'fullscreen',      'hangup',
      'help',       'microphone',         'mute-everyone',   'profile',
      'raisehand',  'security',           'settings',        'sharedvideo',
      'shortcuts',  'stats',              'tileview',
    ];

    return {
      DEFAULT_BACKGROUND,
      DISABLE_FOCUS_INDICATOR: true,
      DISABLE_DOMINANT_SPEAKER_INDICATOR: true,
      DISABLE_VIDEO_BACKGROUND: true,
      INITIAL_TOOLBAR_TIMEOUT: 1000,
      SHOW_CHROME_EXTENSION_BANNER: true,
      TOOLBAR_ALWAYS_VISIBLE: false,
      TOOLBAR_BUTTONS,
      TOOLBAR_TIMEOUT: 2000,
      VERTICAL_FILMSTRIP: false,
      VIDEO_QUALITY_LABEL_DISABLED: true,
    };
  }

  _options() {
    const userInfo = {};
    if (this.email) userInfo.email = this.email;
    if (this.nick) userInfo.displayName = this.nick;

    return {
      configOverwrite: this._configOverwrite(),
      interfaceConfigOverwrite: this._interfaceConfigOverwrite(),
      parentNode: this.targetEl,
      roomName: this.roomName,
      userInfo,
      height: '100%',
      width: '100%',
    };
  }
}
