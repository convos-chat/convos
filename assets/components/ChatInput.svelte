<script>
import {getContext} from 'svelte';
import {l} from '../js/i18n';
import {md} from '../js/md';
import emojione from 'emojione';
import Icon from '../components/Icon.svelte';

export let dialog = {};

let activeAutocompleteIndex = 0;
let autocompleteCategory = 'chat';
let maxNumMatches = 20;
let inputEl;
let pos;

const user = getContext('user');

// TODO: Allow user to select tone in settings
const emojis = {};
Object.keys(emojione.emojioneList).filter(i => !i.match(/_tone/)).sort().forEach(emoji => {
  emoji.match(/(_|:)\w/g).forEach(k => {
    if (!emojis[k]) emojis[k] = [];
    emojis[k].push(emoji);
  });
});

function calculateAutocompleteOptions([before, key, afterKey, after]) {
  const opts = [];

  if (key == ':' && afterKey.length) { // Emojis
    autocompleteCategory = 'emoji';
    [':', '_'].map(p => p + afterKey.substring(0, 1)).filter(group => emojis[group]).forEach(group => {
      for (let i = 0; i < emojis[group].length; i++) {
        if (opts.length >= maxNumMatches) break;
        if (emojis[group][i].indexOf(afterKey) >= 0) opts.push({val: emojis[group][i], text: md(emojis[group][i])});
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
  else if ((key == '#' || key == '&')) { // Group connversations
    autocompleteCategory = 'channel';
    const channels = user.findDialog({connection_id: dialog.connection_id}).channels;
    for (let i = 0; i < channels.length; i++) {
      if (opts.length >= maxNumMatches) break;
      if (channels[i].name.toLowerCase().indexOf(key + afterKey) == -1) continue;
      opts.push({text: channels[i].name, val: channels[i].id});
    }
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
  const msg = {
    connection_id: dialog.connection_id,
    dialog_id: dialog.isDialog ? dialog.id : '',
    message: inputEl.value,
    method: 'send',
  };

  // TODO: Improve handling of "/action ..."
  const action = (msg.message.match(/^\/(\w+)\s*(\S*)/) || ['', 'message', '']).slice(1);
  console.log('TODO', action);

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