import Reactive from './Reactive';
import {loadScript, q} from './util';

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

  async render(targetEl) {
    try {
      const childNodes = [].slice.call(targetEl.children, 0);
      this.targetEl = targetEl;
      this.jitsi = await this._load();
      childNodes.forEach(el => el.remove());
      targetEl.className = targetEl.className.replace(/cms-main/, 'video-chat--wrapper');
      document.querySelector('.cms-navbar').classList.add('is-full-width');
    } catch(err) {
      console.error('[Jitsi]', {err});
      const errorEl = document.querySelector('.video-error');
      errorEl.querySelector('span').textContent = String(err).substring(0, 350);
      errorEl.classList.remove('hidden');
      q(document, '.cms-main .fa-spin', el => el.parentNode.classList.add('hidden'));
    }

    if (!this.jitsi) return this;

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

    return this;
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

  async _load() {
    await loadScript('https://' + this.domain + '/external_api.js');
    return new JitsiMeetExternalAPI(this.domain, this._options());
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
