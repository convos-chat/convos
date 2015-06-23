<sidenav-search>
  <form class="search" onsubmit={startSearch}>
    <div class="input-field">
      <input type="text" id="search_input" placeholder="Search and goto anything" autocomplete="off" spellcheck="false" onkeyup={startSearch}>
    </div>
  </form>
  <ul class="sidenav" if={searchTerm}>
    <li if={!searchResults.length}>
      <div class="alert">
        <i class="material-icons small">warning</i><br>
        Sorry, but our minions failed to find anything
        matching your search for "{searchTerm}".
      </div>
    </li>
    <li each={searchResults} class="link">
      <a href={href} class="waves-effect waves-teal">
        <i class={icon} if={icon}></i>
        {text}
      </a>
    </li>
  </ul>
  <script>

  this.searchTerm = '';
  this.searchResults = [];

  var runSearch = function() {
    var previousSidenav = this.parent.sidenav;
    this.searchTerm = this.search_input.value;

    if (this.searchTerm.length) {
      if (!this.previousSidenav) this.previousSidenav = previousSidenav;
      this.parent.sidenav = 'search';
    }
    else {
      if (this.previousSidenav) this.parent.sidenav = this.previousSidenav;
    }

    if (this.parent.sidenav != previousSidenav) this.parent.update();
  };

  startSearch(e) {
    e.preventDefault();
    if (this.tid) clearTimeout(this.tid);
    this.tid = setTimeout(runSearch.bind(this), 210);
  }

  </script>
</sidenav-search>
