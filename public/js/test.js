// poor mans test suite...
Structure.registerModule('Wirc.Test', {
  run: function() {
    console.log(Wirc.base_url);
    console.log(Wirc.Chat.makeTargetId('target', 1, '#bar'));

    Wirc.Notifier.popup('', 'Running tests...', 'Yay!');
    Wirc.Chat.modifyChannelList({ joined: '#too_cool', cid: 1 });
    setTimeout(function() { Wirc.Chat.modifyChannelList({ parted: '#too_cool', cid: 1 }); }, 500);
    Wirc.Chat.modifyConversationlist({ nick: 'caveman', cid: 1 });
    setTimeout(function() { Wirc.Chat.displayUnread({ target: 'caveman', cid: 1 }); }, 300);
    setTimeout(function() { Wirc.Chat.displayUnread({ cid: 1 }); }, 300);

    console.log(JSON.stringify(Wirc.Chat.parseIrcInput('{"timestamp":1355957508,"nick":"caveman"}')));
    console.log(JSON.stringify(Wirc.Chat.parseIrcInput('{"timestamp":1355957508,"message":"\\u0001ACTION what ever\\u0001"}')));
    console.log(JSON.stringify(Wirc.Chat.parseIrcInput('{"timestamp":1355957508,"message":"hello ' + Wirc.Chat.nick + '"}')));

    Wirc.Chat.onScroll();

    Wirc.Notifier.window_has_focus = false;
    Wirc.Chat.receiveData({ data: '{"cid":1,"timestamp":1355957508,"nick":"caveman","target":"' + Wirc.Chat.target + '","message":"\\u0001ACTION what ever\\u0001"}' });
    Wirc.Chat.receiveData({ data: '{"cid":1,"timestamp":1355957508,"nick":"caveman","target":"' + Wirc.Chat.target + '","message":"hi!"}' });
    Wirc.Chat.receiveData({ data: '{"cid":1,"timestamp":1355957508,"nick":"caveman","target":"' + Wirc.Chat.target + '","message":"what up ' + Wirc.Chat.nick + '"}' });
    Wirc.Chat.receiveData({ data: '{"cid":1,"timestamp":1355957508,"old_nick":"caveman","new_nick":"cavewoman"}' });
    Wirc.Notifier.window_has_focus = true;

    Wirc.Chat.print({ whois: 1, nick: 'yay', user: 'anything', host: 'localhost', realname: 'Mr. Man' });
    Wirc.Chat.print({ whois_channels: 1, nick: 'yay', channels: ['#mojo'] });

    // Need to unfocus the window to make this run. Should blink the tab
    // setTimeout(function() { Wirc.Notifier.title('yikes!'); }, 3000);
  }
});