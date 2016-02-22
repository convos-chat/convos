<sidebar-search>
  <div class="collection">
    <div class="collection-item search">
      <form onsubmit={startSearch}>
        <div class="input-field">
          <input type="text" id="search_input" autocomplete="off" spellcheck="false" onkeyup={startSearch}>
          <label for="search_input">Search and goto anything</label>
        </div>
      </form>
    </div>
    <div class="collection-item" if={!searchResults.length && searchTerm}>
      Sorry, but our minions failed to find anything
      matching your search for "{searchTerm}".
    </div>
    <div each={searchResults} class="link">
      <a href={href} class="waves-effect">
        <i class={icon} if={icon}></i>
        {text}
      </a>
    </div>
  </ul>
  <script>

  this.searchTerm = '';
  this.searchResults = [];

  var runSearch = function() {
    var previous = this.parent.sidebar;
    this.searchTerm = this.search_input.value;

    if (this.searchTerm.length) {
      if (!this.previous) this.previous = previous;
      this.parent.sidebar = 'search';
    }
    else if (this.previous) {
      this.parent.sidebar = this.previous;
    }
    if (this.parent.sidebar != previous) {
      this.parent.update();
    }
  };

  startSearch(e) {
    if (this.tid) clearTimeout(this.tid);
    this.tid = setTimeout(runSearch.bind(this), 210);
  }

  </script>
</sidebar-search>
