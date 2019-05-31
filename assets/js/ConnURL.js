export default class ConnURL extends URL {
  constructor(str) {
    const protocol = str.match(/^\w+:/)[0];
    super(str.replace(/^\w+:/, 'http:')); // new URL() does not understand "irc:" protocol
    this.connProtocol = protocol;
  }

  fromForm(form) {
    if (form.nick.value.length) this.searchParams.append('nick', form.nick.value);
    const server = form.server.value;
    this.host = server.match(/:\d+$/) ? server : server + ':6667';
    this.password = form.password.value;
    this.username = form.username.value;
    return this;
  }

  toString() {
    return this.href.replace(/^http:/, this.connProtocol);
  }
}