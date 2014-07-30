## 0.8 (2014-07-30)
- Fix asking for desktop notifications
- Fix autocomplete: The autocomplete was reset because of keyCode 229 in Chrome
- Fix autcomplete nick order #77
- Fix avatar for localhost users
- Fix creating a new conversation by typing an invalid URL is not possible anymore
- Fix icon in desktop notifications
- Fix login/register screen CSS
- Fix navbar and other dynamic inputs is hidden when priting the conversation
- Fix removing loading indicator even if loading document from cache
- Fix starting convos with ./vendor/bin/carton exec script/convos daemon
- Fix timestamp does not overlap conversation text #96
- Fix will not remove private conversation on /topic in private conversation
- Fix /names in a channel with just you
- Fix "backend" from keeping the hypnotoad socket open
- Add goto-anything #91
- Add reload of conversation on websocket reconnect
- Add Smooth scrolling for sidebar on iphone
- Add timestamp to every message #96
- Add event for invalid channel name
- Will not re-arrange conversation list on reconnect
- Allow going to historic notifications, even if not in that conversation list any more
- Enable to remove conversations (channels) even if not connected to a network #73
- Move the "help" icon from input field to sidebar: This makes it less buggy to type on an iPhone
- New styling for too many tabs in nav.bar #91
- Refactored javascript into more descriptive files
- Replace drop down menus with slide-in sidebars
- Requires Mojolicious 5.16

## 0.7 (2014-06-10)
- Add embedding of GitHub gists
- Fix opening socket in private conversations

## 0.6 (2014-06-09)

- Compatible with Mojolicious 5.0
- New WebSocket keep alive code
- Fix facebook avatars

## 0.5 (2014-05-24)

- Fixed bug with querying people not opening a new tab
- Improved Dockerfile (Dominik Tobschall)
- Fix casing bug with channel names.
- Better scrollbars
- Fixes for iPhone
- Serve echoed messages with 'localhost' instead of hostname.
- Wrap head in &lt;head&gt;
- Whois improvements
- CTCP support
++

## 0.4 (2014-01-28)

- Added system for upgrading Redis schema
- Added API for controlling connections
- Added 'convos upgrade' commmand
- Improved 'convos version' commmand
- Change URL scheme
- Support channels with & prefix (Andreas Vögele)
- Fix start backend from daemon/hypnotoad
- Fix scaling on mobile devices (Alexander Groshev)
- Fix URL detection with URI::Find
- Fix UTF-8 dates (Alexander Groshev)
- Fix starting backend from within Toadfarm

## 0.3 (2013-12-26)

- New setup wizard for installation and better form validation
- Run server embedded by default
- Caching support for Avatars.
- Ensure test suite runs with it's own config.

## 0.2 (2013-12-20)

- Added support for server password
- Improved registration validation
- Redis version detection
- UI Improvements
- Fix bundled Carton
- Improved Docker support (@dz0ny)

## 0.1 (2013-12-12)

- First Public Release
