// MIT License:
//
// Copyright (c) 2010-2012, Joe Walnes
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

/**
 * This behaves like a WebSocket in every way, except if it fails to connect,
 * or it gets disconnected, it will repeatedly poll until it succesfully connects
 * again.
 *
 * It is API compatible, so when you have:
 *   ws = new WebSocket('ws://....');
 * you can replace with:
 *   ws = new ReconnectingWebSocket('ws://....');
 *
 * The event stream will typically look like:
 *  onconnecting
 *  onopen
 *  onpong
 *  onmessage
 *  onmessage
 *  onclose // lost connection
 *  onconnecting
 *  onopen  // sometime later...
 *  onmessage
 *  onmessage
 *  etc... 
 *
 * It is API compatible with the standard WebSocket API.
 *
 * Latest version: https://github.com/joewalnes/reconnecting-websocket/
 * - Joe Walnes
 */
function ReconnectingWebSocket(args) {
    var self = this;
    var ping_interval = args.ping_interval || 20000;
    var forced_close = false;
    var reconnecting = false;
    var connect_tid, ws;

    // attributes
    this.buffer = []
    this.connect_timeout = args.timeout || 10000;
    this.debug = args.debug || location.href.indexOf('ReconnectingWebSocketDebugAll=1') > 0;
    this.ping_protocol = args.ping_protocol || []; // example: [ 'PING', 'PONG' ];
    this.protocols = args.protocols || [];
    this.readyState = WebSocket.CLOSED;
    this.reconnect_interval = args.reconnect_interval || 1000;
    this.url = args.url;
    this.URL = args.url; // Public API

    function connect() {
        readyState('CONNECTING', 'connect');
        emit('onconnecting', reconnecting);
        forced_close = false;
        ws = new WebSocket(self.url, self.protocols);

        if (!connect_tid) {
          connect_tid = setTimeout(
            function() { connect_tid = 0; forced_close = true; emit('ontimeout'); },
            self.connect_timeout
          );
        }

        ws.onopen = function(event) {
            clearTimeout(connect_tid);
            if (self.ping_protocol[0]) self.waiting_for_pong = false;
            event.reconnected = reconnecting;
            reconnecting = true;
            readyState('OPEN', 'onopen');
            emit('onopen', event);
            while(self.buffer.length) self.send(self.buffer.shift());
        };
        ws.onclose = function(event) {
            delete self.waiting_for_pong;
            if (forced_close) {
                readyState('CLOSED', 'onclose');
                emit('onclose', event);
            } else {
                readyState('CONNECTING', 'onclose');
                setTimeout(function() { if (!forced_close) connect(); }, self.reconnect_interval);
            }
        };
        ws.onmessage = function(event) {
            if(self.ping_protocol[1] && event.data == self.ping_protocol[1]) {
              if (self.debug) console.debug('ReconnectingWebSocket', 'pong', event.data);
              self.waiting_for_pong = false;
              emit('onpong', event);
            }
            else {
              emit('onmessage', event);
            }
        };
        ws.onerror = function(event) {
            emit('onerror', event);
        };
    }

    this.send = function(data) {
      if (ws) {
        try {
          var sent = ws.send(data);
          if (sent === false) throw 'Could not to send data to websocket.';
          if (ws.readyState === WebSocket.CLOSED) throw 'WebSocket readyState is CLOSED';
          if (self.debug) console.debug('ReconnectingWebSocket', 'send', data);
        } catch(e) {
          self.buffer.push(data);
          console.error('ReconnectingWebSocket', 'send', data, 'fail', e);
          if (self.readyState != WebSocket.CONNECTING && self.readyState != WebSocket.OPEN) connect();
        };
      }
      else {
        self.buffer.push(data);
        connect();
      }
    };

    this.close = function() {
        console.debug('ReconnectingWebSocket', 'close');
        reconnecting = false;
        if (ws.readyState != WebSocket.CLOSED) {
            forced_close = true;
            ws.close();
        }
        delete self.waiting_for_pong;
    };

    var readyState = function(state, from) {
      console.debug('ReconnectingWebSocket', 'readyState', state, from);
      self.readyState = WebSocket[state];
    }

    var emit = function(name, args) {
      if (self.debug) console.debug('ReconnectingWebSocket', 'emit', name, args);
      if (self[name]) self[name].call(self, args);
    };

    setInterval(
      function() {
        if (typeof self.waiting_for_pong == 'undefined') return;
        if (self.waiting_for_pong) return;
        self.send(self.ping_protocol[0]);
        self.waiting_for_pong = true;
      },
      ping_interval
    );
}
