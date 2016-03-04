(window['mixin'] = window['mixin'] || {})['autocomplete'] = function(tag) {
  var commands = [
    '/me ',
    '/msg ',
    '/query ',   // TODO
    '/join #',
    '/say ',
    '/nick ',
    '/whois ',
    '/close',
    '/part ',
    '/names ',
    '/mode ',    // TODO
    '/topic ',
    '/disconnect',
    '/connect'
  ];

  var before, matches, needle;
  tag.autocomplete = function(input, backwards) {
    if (!this._autocompleteMatches) {
      before = input.value.substring(0, input.selectionStart);
      matches = [];
      needle = '';

      this._autocompleteAfter = input.value.substring(input.selectionStart);
      this._autocompleteBefore = before.replace(/(\S+)\s*$/, function(all, n) {
        needle = n;
        return '';
      });

      matches = matches.concat(this.autocompleteList());

      if (!this._autocompleteBefore.length) {
        matches = matches.concat(commands.filter(function(command) {
          return command.indexOf(needle) == 0;
        }));
      }

      this._autocompleteIndex = -1;
      this._autocompleteMatches = matches;
    }

    matches = this._autocompleteMatches;
    if (!matches.length) return;

    this._autocompleteIndex += backwards ? -1 : 1;
    if (this._autocompleteIndex < 0) this._autocompleteIndex = matches.length - 1;
    if (this._autocompleteIndex == matches.length) this._autocompleteIndex = 0;

    input.value = this._autocompleteBefore + matches[this._autocompleteIndex];
  }.bind(tag);

  tag.autocompleteList = function() {
    return []; // TODO: Return participants in conversation
  };

  return tag;
};
