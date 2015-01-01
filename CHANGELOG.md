## 0.8603 (2015-01-01)
- Fix new Twitter javascript which could not be assetpacked

## 0.8602 (2014-11-15)
- Fix starting convos as "daemon" with embedded backend

## 0.8601 (2014-10-26)
- Fix error in reconnect method.
- Disable init script tests by default

## 0.86 (2014-10-24)
- Fix sourcing /etc/default/convos from init script
- Deprecated Convos::Command::backend
- Deprecated Convos::Command::upgrade

## 0.85 (2014-10-24)
- Fix input field in iOS #167
- Fix nick-list event #197
- Fix rendering /list command with correct height #205
- Fix wrong kick message #206
- Fix scrolling to bottom when gist load #207
- Fix sending server messages to server log, instead of opening new conversation #209
- Fix uppercase characters in login name #211
- Fix handling of nicks starting with "[" or "}" #219
- Stop backend from going bananas, using Daemon::Control #224
  - Remove CONVOS_BACKEND_EMBEDDED as exposed variable
  - Remove CONVOS_MANUAL_BACKEND
- Add delete_user() to Convos::Core #104
- Add feedback when websocket could not be established #192
- Add /profile/delete #104
- Add detection if unable to connect to websocket #173
- Add Convos::Manual::Running #224
  - https://github.com/Nordaaker/convos/blob/master/lib/Convos/Manual/Running.pod
- Add improved embed of media with Mojolicious::Plugin::LinkEmbedder 0.12
  * Fix embedding YouTube video over https
  * Fix video site that also contain meta information, but no video
  * Add Github embedding of projects, issues and pull requests
  * Add Open graph and Twitter meta information
  * Faster loading of media using cache mechanism
- Add backoff and throttling of connections #227
- Convos can now generate init scripts for backend/frontend #225 #224
- Change to only show err_nicknameinuse message once #176
- Change to "flat" design
- Change to reload notification list when reconnect to backend #221
- Remove Convos::Loopback
- Remove references to Heroku, closes #80
- Remove desktop notification status in profile #203
- Remove /convos resource. Going directly to server log instead #220

## 0.84 (2014-09-14)
- Fix update of current nick()
- Fix refreshing conversation and navbar when clicking back/forward buttons in browser #111
- Fix vendor/bin/carton can be run with Perl 5.12 #144
- Fix commands are now case insensitive #168
- Improved registration process #121
- Improved README.md #182
- Add auto-detect of TLS #121
- Add prompt user to join a channel on connect #121
- Add support for /list to show channel list #131
- Add support for password protected server connection #159
- Add support for archive of IRC log to disk or ElasticSearch #172
- Change welcome message and prompt the user to join a channel on first connect #121
- Change to showing server messages after first time register #121
- Change to Mojolicious::Plugin::FontAwesome4 for icons #162
- Remove support for Heroku #177
- Include NOTICE in messages

## 0.83 (2014-09-01)
- Fix highlighting of multiple channels #137
- Fix connection actions in sidebar #157
- Fix autocomplete will not match offline nicks #129
- Add number of participants #136
- Add /names will be displayed with nick modes #138
- Add visual indicator for when a new day starts #149
- Add down arrow to clear input field #151
- Add support for kicked event #134
- Add highlight for new messages since last time window had focus #56
- Add /kick command #134
- Various UI improvements (Flatten, highlights/background go all out) #145, #146, #147, #162

## 0.82 (2014-08-24)
- Requires IO::Socket::SSL 1.84
- Requires Mojolicious 5.30
- Fix nicks starting with special character, #130
- Fix jumpy text when sending a message
- Fix invite only template styling
- Fix /help command and add click actions
- Fix missing special characters in nicks, #130
- Default to no CONVOS_INVITE_CODE in Dockerfile, #118
- Improvements on Android, #132
- Fetch avatar on client side, #133
- Will remember channel key on "/join #channel s3cret", #127

## 0.81 (2014-08-07)
- Fix typos in Docker file #114
- Do not need config file anymore #102
- Add support for CONVOS_ORGANIZATION_NAME #102
- Add support for custom templates #102
- Add more restrictive /:network/*target route #112
- Change avatars to be cached in browser #113

## 0.8002 (2014-07-31)
- Fix UNAUTHORIZED release

## 0.8001 (2014-07-31)
- Fix "same-nick" class was appended to wrong element
- Squelch not connected message for 'convos' default network.

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
