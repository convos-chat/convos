<script>
import autocomplete from '../js/autocomplete';
import Icon from '../components/Icon.svelte';
import {getContext} from 'svelte';
import {extractErrorMessage} from '../js/util';
import {l} from '../js/i18n';

export const uploader = uploadFiles;
export let conversation = {};
export function getUploadEl() { return uploadEl }
export function setValue(val) { inputEl.value = val }

let activeAutocompleteIndex = 0;
let autocompleteCategory = 'none';
let inputEl;
let pos = 0;
let uploadEl;

const api = getContext('api');
const user = getContext('user');

$: autocompleteOptions = calculateAutocompleteOptions(inputParts) || [];
$: connection = user.findConversation({connection_id: conversation.connection_id});
$: inputParts = calculateInputParts(pos);
$: nick = connection && connection.nick;
$: placeholder = conversation.is('search') ? 'What are you looking for?' : connection && connection.is('unreachable') ? l('Connecting...') : l('What is on your mind %1?', nick);
$: sendIcon = conversation.is('search') ? 'search' : 'paper-plane';

export function add(str, params = {}) {
  const space = params.space || '';
  inputEl.value = inputParts[0] + str + space + inputParts[3];
  inputEl.selectionStart = inputEl.selectionEnd = (inputParts[0] + str + space).length;
  if (space.length) pos = inputEl.selectionStart;
}

function calculateAutocompleteOptions([before, key, afterKey, after]) {
  autocompleteCategory =
      key == ':' && afterKey.length ? 'emojis'
    : key == '/' && !before.length  ? 'commands'
    : key == '@' && afterKey.length ? 'nicks'
    : key == '#' || key == '&'      ? 'conversations'
    :                                 'none';

  activeAutocompleteIndex = 0;
  const opts = autocomplete(autocompleteCategory, {conversation, query: key + afterKey, user});
  if (opts.length) opts.unshift({val: key + afterKey});
  return opts;
}

function calculateInputParts(pos) {
  if (!inputEl) return ['', '', '', ''];

  let key = '';
  let afterKey = '';
  const before = inputEl.value.substring(0, pos).replace(/(\S)(\S*)$/, (a, b, c) => {
    key = b;
    afterKey = c;
    return '';
  });

  return [before, key, afterKey, inputEl.value.substring(pos)];
}

function fillinAutocompeteOption(params) {
  const autocompleteOpt = autocompleteOptions[activeAutocompleteIndex];
  if (autocompleteOpt) add(autocompleteOpt.val, params);
}

function focusAutocompleteItem(e, moveBy) {
  if (!autocompleteOptions.length) return;
  e.preventDefault();
  activeAutocompleteIndex += moveBy;
  if (activeAutocompleteIndex < 0) activeAutocompleteIndex = autocompleteOptions.length - 1;
  if (activeAutocompleteIndex >= autocompleteOptions.length) activeAutocompleteIndex = 0;
  fillinAutocompeteOption({space: ''});
}

function handleMessageResponse(msg) {
  if (!msg.errors) return;
  if (!conversation || msg.conversation_id == conversation.conversation_id) return;
  conversation.addMessage({...msg, message: 'Message "%1" failed: %2', type: 'error', vars: [msg.message, extractErrorMessage(msg.errors)]});
}

function selectOption(e) {
  activeAutocompleteIndex = parseInt(e.target.closest('a').href.replace(/.*index:/, ''), 10);
  fillinAutocompeteOption({space: ' '});
  inputEl.focus();
}

export function sendMessage(e) {
  if (e.preventDefault) e.preventDefault();
  const msg = {method: 'send'};
  msg.message = e.preventDefault ? inputEl.value : e.message;

  // Aliases
  msg.message = msg.message.replace(/^\/close/i, '/part');
  msg.message = msg.message.replace(/^\/j\b/i, '/join');
  msg.message = msg.message.replace(/^\/raw/i, '/quote');

  if (msg.message.length) conversation.send(msg).then(handleMessageResponse);
  if (!conversation.is('search')) inputEl.value = '';

  pos = 0;
}

function uploadFiles(e) {
  const files = (e.target && e.target.files) || (e.dataTransfer && e.dataTransfer.files);
  if (!files || !files.length) return;
  if (files.length > 1) return console.log('Cannot upload more than one file.');

  const formData = new FormData();
  formData.append('file', files[0]);
  api('uploadFile').perform({formData}).then(op => {
    const res = op.res.body;
    if (res.files && res.files.length) return add(res.files[0].url);
    if (res.errors) conversation.addMessage({message: 'Could not upload file: %1', vars: [l(extractErrorMessage(res.errors))], type: 'error'});
  });
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
      sendMessage(e);
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
</script>

<form class="chat-input" on:submit|preventDefault>
  <textarea class="is-primary-input"
    placeholder="{placeholder}"
    bind:this="{inputEl}"
    on:change="{e => {pos = inputEl.selectionStart}}"
    on:keydown="{e => (keys[e.key] || keys.Fallback)(e)}"
    on:keyup="{e => keys.Release(e)}"></textarea>

  <label class="upload is-hallow" hidden="{!conversation.is('conversation')}">
    <input type="file" on:change="{uploadFiles}" bind:this="{uploadEl}">
    <Icon name="cloud-upload-alt"/>
  </label>

  <button type="buttton" on:click="{sendMessage}" class="btn chat-input__send"><Icon name="{sendIcon}"/></button>

  <div class="chat-input_autocomplete chat-input_autocomplete_{autocompleteCategory}" hidden="{!autocompleteOptions.length}">
    {#each autocompleteOptions as opt, i}
      <a href="#index:{i}" class:has-focus="{i == activeAutocompleteIndex}" on:click|preventDefault="{selectOption}" tabindex="-1">{@html opt.text || opt.val}</a>
    {/each}
  </div>
</form>
