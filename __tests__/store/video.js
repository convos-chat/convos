import Conversation from '../../assets/store/Conversation';
import {videoService, videoWindow} from '../../assets/store/video';

describe('videoService', () => {
  test('get', () => {
    expect(videoService.get()).toBe(null);
  });

  test('fromString', () => {
    videoService.fromString('https://meet.jit.si/');
    expect(videoService.get().href).toBe('https://meet.jit.si/');
  });

  test('conversationToExternalUrl', () => {
    const conversation = new Conversation({name: 'CoolBeans'});
    videoService.fromString('');
    expect(videoService.conversationToExternalUrl(conversation)).toBe(null);

    videoService.fromString('https://meet.jit.si/');
    expect(videoService.conversationToExternalUrl(conversation)).toBe('https://meet.jit.si/coolbeans');
  });

  test('conversationToInternalUrl', () => {
    const conversation = new Conversation({name: 'CoolBeans'});
    videoService.fromString('');
    expect(videoService.conversationToInternalUrl(conversation)).toBe(null);

    videoService.fromString('https://meet.jit.si/');
    expect(videoService.conversationToInternalUrl(conversation)).toBe('http://localhost/video/meet.jit.si/coolbeans');
  });
});

describe('videoWindow', () => {
  let closed = 0;
  let opened = [];
  videoWindow.window = {
    open: (url) => {
      opened.push(url);
      return {addEventListener: () => {}, close: () => closed++};
    },
  };

  test('get', () => {
    expect(videoWindow.get()).toBe(null);
  });

  test('open', () => {
    opened = [];
    videoWindow.open('/video/meet.jit.si/coolbeans');
    expect(opened).toEqual(['/video/meet.jit.si/coolbeans']);

    opened = [];
    videoWindow.open('/video/meet.jit.si/coolbeans', {nick: 'ca+ve'});
    expect(opened).toEqual(['/video/meet.jit.si/coolbeans?nick=ca%2Bve']);
  });

  test('close', () => {
    videoWindow.close();
    videoWindow.close(); // Ignored
    expect(closed).toBe(1);
  });
});
