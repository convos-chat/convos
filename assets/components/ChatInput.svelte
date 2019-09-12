<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import autocomplete from '../js/autocomplete';
import Icon from '../components/Icon.svelte';

export let dialog = {};

let activeAutocompleteIndex = 0;
let autocompleteCategory = 'none';
let inputEl;
let pos;

const user = getContext('user');

function calculateAutocompleteOptions([before, key, afterKey, after]) {
  autocompleteCategory =
      key == ':' && afterKey.length ? 'emojis'
    : key == '/' && !before.length  ? 'commands'
    : key == '@' && afterKey.length ? 'nicks'
    : key == '#' || key == '&'      ? 'channels'
    :                                 'none';

  activeAutocompleteIndex = 0;
  const opts = autocomplete(autocompleteCategory, {dialog, query: key + afterKey, user});
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
  const msg = {message: inputEl.value, method: 'send', dialog};
  const action = (msg.message.match(/^\/(\w+)\s*(\S*)/) || ['', 'message', '']).slice(1);

  if (msg.message.length) user.send(msg);
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
$: connection = user.findDialog({connection_id: dialog.connection_id});
$: inputParts = pos && calculateInputParts(pos) || ['', '', '', ''];
</script>

<div class="chat-input">
  <textarea
    placeholder="{l('What is on your mind %1?', $connection.nick)}"
    bind:this="{inputEl}"
    on:keydown="{e => (keys[e.key] || keys.Fallback)(e)}"
    on:keyup="{e => keys.Release(e)}"></textarea>

  <a href="#send" on:click|preventDefault="{sendMessage}" class="btn-send"><Icon name="paper-plane"/></a>

  <div class="chat-input_autocomplete chat-input_autocomplete_{autocompleteCategory}" hidden="{!autocompleteOptions.length}">
    {#each autocompleteOptions as opt, i}
      <a href="#{opt.value}" class:has-focus="{i == activeAutocompleteIndex}" tabindex="-1" on:click|preventDefault="{e => fillinAutocompeteOption({space: ''})}">{@html opt.text || opt.val}</a>
    {/each}
  </div>
</div>
