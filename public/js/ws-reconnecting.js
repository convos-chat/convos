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
function ReconnectingWebSocket(url, protocols) {
    protocols = protocols || [];

    // These can be altered by calling code.
    this.debug = location.href.indexOf('ReconnectingWebSocketDebugAll=1') > 0;
    this.buffer = []
    this.reconnectInterval = 1000;
    this.timeoutInterval = 2000;
    this.ping_interval = 20000;
    this.ping_protocol = [ 'PING', 'PONG' ];

    var self = this;
    var ws;
    var forcedClose = false;
    var timedOut = false;
    var ping_tid;
    
    this.url = url;
    this.protocols = protocols;
    this.readyState = WebSocket.CLOSED;
    this.URL = url; // Public API

    this.onopen = function(event) {
    };

    this.onclose = function(event) {
    };

    this.onconnecting = function(event) {
    };

    this.onmessage = function(event) {
    };

    this.onerror = function(event) {
    };

    function connect(reconnectAttempt) {
        ws = new WebSocket(url, protocols);
        
        self.readyState = WebSocket.CONNECTING;
        self.onconnecting();
        if (self.debug) console.debug('ReconnectingWebSocket', 'attempt-connect', url);
        
        var localWs = ws;
        var timeout = setTimeout(function() {
            if (self.debug) console.debug('ReconnectingWebSocket', 'connection-timeout', url);
            timedOut = true;
            localWs.close();
            timedOut = false;
        }, self.timeoutInterval);
        
        ws.onopen = function(event) {
            clearTimeout(timeout);
            if (self.debug) console.debug('ReconnectingWebSocket', 'onopen', url);
            if (self.ping_protocol[0]) self.waiting_for_pong = false;
            self.readyState = WebSocket.OPEN;
            reconnectAttempt = false;
            self.onopen(event);
            while(self.buffer.length) self.send(self.buffer.shift());
        };
        
        ws.onclose = function(event) {
            clearTimeout(timeout);
            ws = null;
            if (forcedClose) {
                self.readyState = WebSocket.CLOSED;
                self.onclose(event);
            } else {
                self.readyState = WebSocket.CONNECTING;
                self.onconnecting();
                if (!reconnectAttempt && !timedOut) {
                    if (self.debug) console.debug('ReconnectingWebSocket', 'onclose', url);
                    self.onclose(event);
                }
                setTimeout(function() { connect(true); }, self.reconnectInterval);
            }
        };
        ws.onmessage = function(event) {
            if (self.debug) {
                console.debug('ReconnectingWebSocket', 'onmessage', url, event.data);
            }
            if(self.ping_protocol[1] && event.data == self.ping_protocol[1]) {
              self.waiting_for_pong = false;
            }
            else {
              self.onmessage(event);
            }
        };
        ws.onerror = function(event) {
            if (self.debug) console.debug('ReconnectingWebSocket', 'onerror', url, event);
            self.onerror(event);
        };
    }

    this.send = function(data) {
        try {
          ws.send(data);
          if(self.debug) console.debug('ReconnectingWebSocket', 'send', url, data);
        } catch(e) {
          connect(url);
          self.buffer.push(data);
          if(self.debug) console.debug('ReconnectingWebSocket', 'buffer.push', data, e);
          if(self.readyState != WebSocket.CONNECTING && self.readyState != WebSocket.OPEN) connect(url);
        };
    };

    this.close = function() {
        if (ws) {
            forcedClose = true;
            ws.close();
        }
    };

    /**
     * Additional public API method to refresh the connection if still open (close, re-open).
     * For example, if the app suspects bad data / missed heart beats, it can try to refresh.
     */
    this.refresh = function() {
        if (ws) ws.close();
    };

    setInterval(
      function() {
        if(typeof self.waiting_for_pong == 'undefined') return;
        if(self.waiting_for_pong) return self.refresh();
        ws.send(self.ping_protocol[0]);
        self.waiting_for_pong = true;
      },
      self.ping_interval
    );
}
