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
   * fromForm() can be used to copy connection parameters from a form to the URL.
   *
   * @memberof ConnectionURL
   * @param {HTMLFormElement} form A form element, with input fields.
   * @return {this}
   */
  fromForm(form) {
    const server = form.server.value;
    if (form.nick.value.length) this.searchParams.append('nick', form.nick.value);
    this.searchParams.append('tls', form.tls.checked ? '1' : '0');
    this.searchParams.append('tls_verify', form.tls_verify && form.tls_verify.checked ? '1' : '0');
    this.host = server.match(/:\d+$/) ? server : server + ':6667';
    this.password = form.password.value;
    this.username = form.username.value;
    return this;
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
