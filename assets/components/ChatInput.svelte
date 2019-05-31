<script>
import {l} from '../js/i18n';
import {md} from '../js/md';
import emojione from 'emojione';
import Icon from '../components/Icon.svelte';

let activeAutocompleteIndex = 0;
let autocompleteCategory = 'chat';
let maxNumMatches = 20;
let inputEl;
let pos;

// TODO: Allow user to select tone in settings
const emojis = Object.keys(emojione.emojioneList).filter(i => !i.match(/_tone/)).sort();

function calculateAutocompleteOptions([before, key, afterKey, after]) {
  const opts = [];

  if (key == ':' && afterKey.length) { // Emojis
    autocompleteCategory = 'emoji';
    [new RegExp('^:' + afterKey), new RegExp('_' + afterKey)].forEach(re => {
      for (let i = 0; i < emojis.length; i++) {
        if (emojis[i].match(re)) opts.push({val: emojis[i], text: md(emojis[i])});
        if (opts.length >= maxNumMatches) break;
      }
    });
  }
  else if (key == '/' && afterKey.length) { // Commands
    console.log('TODO: Autocomplete commands ' + afterKey);
  }
  else if (key == '@' && afterKey.length) { // Private conversations
    console.log('TODO: Autocomplete private conversations ' + afterKey);
    autocompleteCategory = 'nick';
  }
  else if ((key == '#' || key == '&') && afterKey.length) { // Group connversations
    console.log('TODO: Autocomplete group conversations ' + afterKey);
    autocompleteCategory = 'channel';
  }

  activeAutocompleteIndex = 0;
  if (opts.length) opts.unshift({val: key + afterKey});
  return opts;
}

function calculateInputParts(pos) {
  let key = '';
  let afterKey = '';
  const before = inputEl.value.substring(0, pos).replace(/(\S)(\S*)$/, (a, b, c) => {
    key = b;
    afterKey = c;
    return '';
  });

  return [before, key, afterKey, inputEl.value.substring(pos)];
}

function fillinAutocompeteOption({space}) {
  const autocompleteOpt = autocompleteOptions[activeAutocompleteIndex];
  if (!autocompleteOpt) return;
  inputEl.value = inputParts[0] + autocompleteOpt.val + space + inputParts[3];
  inputEl.selectionStart = inputEl.selectionEnd = (inputParts[0] + autocompleteOpt.val + space).length;
  if (space.length) pos = inputEl.selectionStart;
}

function focusAutocompleteItem(e, moveBy) {
  if (!autocompleteOptions.length) return;
  e.preventDefault();
  activeAutocompleteIndex += moveBy;
  if (activeAutocompleteIndex < 0) activeAutocompleteIndex = autocompleteOptions.length - 1;
  if (activeAutocompleteIndex >= autocompleteOptions.length) activeAutocompleteIndex = 0;
  fillinAutocompeteOption({space: ''});
}

function sendMessage() {
  console.log('TODO: sendMessage', inputEl.value);
  inputEl.value = '';
}

const keys = {
  ArrowDown: (e) => focusAutocompleteItem(e, e.shiftKey ? 4 : 1),
  ArrowUp: (e) => focusAutocompleteItem(e, e.shiftKey ? -4 : -1),
  Tab: (e) => focusAutocompleteItem(e, e.shiftKey ? -1 : 1),
  Enter(e) {
    const autocompleteOpt = autocompleteOptions[activeAutocompleteIndex];
    if (autocompleteOpt) {
      e.preventDefault();
      fillinAutocompeteOption({space: ' '});
    }
    else if (!e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  },
  Fallback(e) {
    // console.log('ChatInput', e);
  },
  Release(e) {
    const updatePosKeys = ['ArrowLeft', 'ArrowRight', 'Backspace'];
    if (e.key.length == 1 || updatePosKeys.indexOf(e.key) != -1) pos = inputEl.selectionStart;
  },
};

$: autocompleteOptions = calculateAutocompleteOptions(inputParts) || [];
$: inputParts = pos && calculateInputParts(pos) || ['', '', '', ''];
</script>

<div class="chat-input">
  <textarea
    placeholder="{l('What is on your mind?')}"
    bind:this="{inputEl}"
    on:keydown="{e => (keys[e.key] || keys.Fallback)(e)}"
    on:keyup="{e => keys.Release(e)}"></textarea>

  <a href="#send" on:click|preventDefault="{sendMessage}" class="btn-send"><Icon name="paper-plane"/></a>

  <div class="chat-input_autocomplete chat-input_autocomplete_{autocompleteCategory} {autocompleteOptions.length ? '' : 'hide'}">
    {#each autocompleteOptions as opt, i}
      <a href="#{opt.value}" class:has-focus="{i == activeAutocompleteIndex}" tabindex="-1" on:click|preventDefault="{e => fillinAutocompeteOption({space: ''})}">{@html opt.text || opt.val}</a>
    {/each}
  </div>
</div>