/**
 * ConnectionURL can be used to represent an URL that does not start with "http" or
 * "https".
 *
 * @exports ConnectionURL
 * @class ConnectionURL
 */

export default class ConnectionURL {
  constructor(href) {
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

  /**
   * Will return a string with the custom protocol.
   *
   * @memberof ConnectionURL
   */
  toString() {
    return this.href.replace(/^http:/, this.protocol);
  }
}
