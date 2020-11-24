<script>
import Icon from '../components/Icon.svelte';
import {calculateAutocompleteOptions as _calculateAutocompleteOptions, fillIn as _fillIn} from '../js/autocomplete';
import {getContext} from 'svelte';
import {extractErrorMessage} from '../js/util';
import {l} from '../js/i18n';

export const uploader = uploadFiles;
export let conversation;
export let value = '';

let cursorPos = 0;
let splitValueAt = 0;

const api = getContext('api');
const user = getContext('user');

$: autocompleteIndex = splitValueAt && 0; // set it to zero when splitValueAt changes
$: autocompleteOptions = calculateAutocompleteOptions(splitValueAt);
$: autocompleteCategory = autocompleteOptions.length && autocompleteOptions[0].autocompleteCategory || 'none';
$: connection = user.findConversation({connection_id: conversation.connection_id});
$: nick = connection && connection.nick;
$: placeholder = conversation.is('search') ? 'What are you looking for?' : connection && connection.is('unreachable') ? l('Connecting...') : l('What is on your mind %1?', nick);
$: sendIcon = conversation.is('search') ? 'search' : 'paper-plane';
$: updateValueWhenConversationChanges(conversation);

function calculateAutocompleteOptions(splitValueAt) {
  return _calculateAutocompleteOptions(value, splitValueAt, {conversation, user});
}

function fillin(str, params) {
  const {before, middle, after} = _fillIn(str, {...params, cursorPos, value});
  cursorPos = (before + middle).length;
  value = before + middle + after;
  conversation.update({userInput: value});
}

function focusAutocompleteItem(e, moveBy) {
  if (!autocompleteOptions.length) return;
  e.preventDefault();
  autocompleteIndex += moveBy;
  if (autocompleteIndex < 0) autocompleteIndex = autocompleteOptions.length - 1;
  if (autocompleteIndex >= autocompleteOptions.length) autocompleteIndex = 0;
  fillin(autocompleteOptions[autocompleteIndex], {replace: true});
}

function handleMessageResponse(msg) {
  if (!msg.errors) return;
  if (!conversation || msg.conversation_id == conversation.conversation_id) return;
  conversation.addMessage({...msg, message: 'Message "%1" failed: %2', type: 'error', vars: [msg.message, extractErrorMessage(msg.errors)]});
}

function onReady(inputEl, params) {
  inputEl.addEventListener('change', () => {
    cursorPos = splitValueAt = inputEl.selectionStart;
    value = inputEl.value;
    conversation.update({userInput: value});
  });

  inputEl.addEventListener('keydown', (e) => {
    if (e.key == 'ArrowDown') return focusAutocompleteItem(e, e.shiftKey ? 4 : 1);
    if (e.key == 'ArrowUp') return focusAutocompleteItem(e, e.shiftKey ? -4 : -1);
    if (e.key == 'Enter') return selectOptionOrSendMessage(e);
    if (e.key == 'Tab') return focusAutocompleteItem(e, e.shiftKey ? -1 : 1);
  });

  inputEl.addEventListener('keyup', (e) => {
    value = inputEl.value;
    conversation.update({userInput: value});
    const updatePosKeys = ['ArrowLeft', 'ArrowRight', 'Backspace'];
    if (e.key.length == 1 || updatePosKeys.indexOf(e.key) != -1) cursorPos = splitValueAt = inputEl.selectionStart;
  });

  onUpdate(inputEl, params);
  return {update: (params) => onUpdate(inputEl, params)};
}

function onUpdate(inputEl, {cursorPos, value}) {
  if (inputEl.value != value) inputEl.value = value; // Prevent recursion
  if (inputEl.selectionStart == inputEl.selectionEnd) inputEl.selectionStart = inputEl.selectionEnd = cursorPos;
}

function selectOption(e) {
  autocompleteIndex = parseInt(e.target.closest('a').href.replace(/.*index:/, ''), 10);
  fillin(autocompleteOptions[autocompleteIndex], {padAfter: true, replace: true});
  splitValueAt = cursorPos;
}

function selectOptionOrSendMessage(e = {}) {
  const autocompleteOpt = autocompleteOptions[autocompleteIndex];
  if (autocompleteOpt) {
    e.preventDefault();
    fillin(autocompleteOptions[autocompleteIndex], {padAfter: true, replace: true});
    splitValueAt = cursorPos;
  }
  else if (!e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
    e.preventDefault();
    const msg = {method: 'send'};
    msg.message = value;

    // Aliases
    msg.message = msg.message.replace(/^\/close/i, '/part');
    msg.message = msg.message.replace(/^\/j\b/i, '/join');
    msg.message = msg.message.replace(/^\/raw/i, '/quote');

    if (msg.message.length) conversation.send(msg).then(handleMessageResponse);
    if (!conversation.is('search')) {
      conversation.update({userInput: ''});
      splitValueAt = 0;
      value = '';
    }
  }
}

function updateValueWhenConversationChanges(conversation) {
  if (updateValueWhenConversationChanges.lock == conversation.path) return;
  updateValueWhenConversationChanges.lock = conversation.path;
  value = typeof conversation.userInput == 'undefined' ? '' : conversation.userInput;
}

function uploadFiles(e) {
  const files = (e.target && e.target.files) || (e.dataTransfer && e.dataTransfer.files);
  if (!files || !files.length) return;
  if (files.length > 1) return conversation.addMessage({message: 'Cannot upload more than one file.', type: 'error'});

  const formData = new FormData();
  formData.append('file', files[0]);
  api('uploadFile').perform({formData}).then(op => {
    const res = op.res.body;
    if (res.files && res.files.length) return fillin(res.files[0].url, {append: true});
    if (res.errors) conversation.addMessage({message: 'Could not upload file: %1', vars: [l(extractErrorMessage(res.errors))], type: 'error'});
  });
}
</script>

<form class="chat-input" on:submit|preventDefault>
  <textarea class="is-primary-input" placeholder="{placeholder}" use:onReady="{{cursorPos, value}}"></textarea>

  <label class="upload is-hallow" hidden="{!conversation.is('conversation')}">
    <input type="file" on:change="{uploadFiles}"/>
    <Icon name="cloud-upload-alt"/>
  </label>

  <button type="buttton" on:click="{selectOptionOrSendMessage}" class="btn chat-input__send"><Icon name="{sendIcon}"/></button>

  <div class="chat-input_autocomplete chat-input_autocomplete_{autocompleteCategory}" hidden="{!autocompleteOptions.length}">
    {#each autocompleteOptions as opt, i}
      <a href="#index:{i}" class:has-focus="{i == autocompleteIndex}" on:click|preventDefault="{selectOption}" tabindex="-1">{@html opt.text || opt.val}</a>
    {/each}
  </div>
</form>
