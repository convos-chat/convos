/**
 * ConnectionURL can be used to represent an URL that does not start with "http" or
 * "https".
 *
 * @exports ConnectionURL
 * @class ConnectionURL
 */

import {is} from './util';

export default class ConnectionURL {
  constructor(href = 'http://localhost') {
    this._url = new URL('http://localhost');

    Object.defineProperty(this, 'href', {
      get: () => this._url.href.replace(/^http:/, this.protocol),
      set: (href) => {
        this._url.href = href.replace(/^\w+:/, 'http:');
        this.protocol = href.match(/^\w+:/)[0];
      },
    });

    ['host', 'pathname', 'password', 'searchParams', 'username'].forEach(name => {
      Object.defineProperty(this, name, {
        get: () => this._url[name],
        set: (val) => {this._url[name] = val},
      });
    });

    this.href = href;
  }

  fromFields(fields) {
    if (is.string(fields.protocol)) this.protocol = fields.protocol;
    if (is.string(fields.host)) this.host = fields.host;
    if (is.string(fields.password)) this.password = fields.password;
    if (is.string(fields.username)) this.username = fields.username;
    if (is.string(fields.conversation_id)) this.pathname = encodeURIComponent(fields.conversation_id);

    const searchParams = this.searchParams;
    if (is.string(fields.nick)) searchParams.append('nick', fields.nick.trim());
    if (is.string(fields.realname) && fields.realname.length) searchParams.append('realname', fields.realname.trim());
    if (is.string(fields.sasl)) searchParams.append('sasl', fields.sasl || 'none');
    searchParams.append('tls', is.true(fields.tls) ? '1' : '0');
    searchParams.append('tls_verify', is.true(fields.tls) && is.true(fields.tls_verify) ? '1' : '0');

    return this;
  }

  toFields(fields = {}) {
    fields.protocol = this.protocol;
    fields.host = this.host;
    fields.password = is.string(this.password) ? this.password : '';
    fields.username = is.string(this.username) ? this.username : '';
    fields.conversation_id = decodeURIComponent(this.pathname.split('/').filter(p => p.length)[0] || '');

    const searchParams = this.searchParams;
    fields.nick = searchParams.get('nick') || fields.nick || '';
    fields.realname = searchParams.get('realname') || fields.realname || '';
    fields.sasl = searchParams.get('sasl') || fields.sasl || 'none';
    fields.realname = searchParams.get('realname') || fields.realname || '';
    fields.tls = is.true(searchParams.get('tls'));
    fields.tls_verify = is.true(searchParams.get('tls_verify'));

    return fields;
  }

  /**
   * Will return a string with the custom protocol.
   *
   * @memberof ConnectionURL
   */
  toString() {
    return this.href.replace(/^http:/, this.protocol);
  }
}
