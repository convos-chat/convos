(window['mixin'] = window['mixin'] || {})['autocomplete'] = function(tag) {
  var before, matches, needle;
  var commands = [
    '/me ',
    '/msg ',
    '/query ',   // TODO
    '/join #',
    '/say ',
    '/nick ',
    '/whois ',
    '/names',
    '/close',
    '/part ',
    '/mode ',    // TODO
    '/topic ',
    '/disconnect',
    '/connect'
  ];

  tag.autocomplete = function(input, backwards) {
    if (!this.autocompleteMatches) {
      before = input.value.substring(0, input.selectionStart);
      needle = '';

      this._autocompleteAfter = input.value.substring(input.selectionStart);
      this._autocompleteBefore = before.replace(/(\S+)\s*$/, function(all, n) {
        needle = n;
        return '';
      });

      matches = [needle].concat(this.autocompleteList(this._autocompleteBefore, needle, this._autocompleteAfter));
      if (!this._autocompleteBefore.length) matches = matches.concat(commands);
      matches = matches.filter(function(command) { return !command.indexOf(needle); });
      this._autocompleteIndex = 0;
      this.autocompleteMatches = matches;
    }

    matches = this.autocompleteMatches;
    if (!matches.length) return;

    this._autocompleteIndex += backwards ? -1 : 1;
    if (this._autocompleteIndex < 0) this._autocompleteIndex = matches.length - 1;
    if (this._autocompleteIndex == matches.length) this._autocompleteIndex = 0;

    input.value = this._autocompleteBefore + matches[this._autocompleteIndex];
  }.bind(tag);

  // override this in consumer object
  tag.autocompleteList = function(before, needle, after) {
    return [];
  };

  return tag;
};
