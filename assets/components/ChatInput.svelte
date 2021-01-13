<script>
import Icon from '../components/Icon.svelte';
import {calculateAutocompleteOptions, fillIn as _fillIn} from '../js/autocomplete';
import {getContext} from 'svelte';
import {l} from '../store/I18N';
import {extractErrorMessage} from '../js/util';

export const uploader = uploadFiles;
export let conversation;

let autocompleteIndex = 0;
let autocompleteOptions = [];
let autocompleteCategory = 'none';
let inputEl;
let splitValueAt = 0;

const api = getContext('api');
const user = getContext('user');

$: connection = user.findConversation({connection_id: conversation.connection_id});
$: nick = connection && connection.nick;
$: placeholder = conversation.is('search') ? 'What are you looking for?' : connection && connection.is('unreachable') ? $l('Connecting...') : $l('What is on your mind %1?', nick);
$: sendIcon = conversation.is('search') ? 'search' : 'paper-plane';
$: startAutocomplete(splitValueAt);
$: updateValueWhenConversationChanges(conversation);

function fillin(str, params) {
  const {before, middle, after} = _fillIn(str, {...params, cursorPos: inputEl.selectionStart, value: inputEl.value});
  setValue(before + middle + after);
  inputEl.selectionStart = inputEl.selectionEnd = (before + middle).length;
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

function onChange(inputEl) {
  autocompleteIndex = 0;
  splitValueAt = inputEl.selectionStart;
  conversation.update({userInput: inputEl.value});
}

function onReady(el) {
  inputEl = el;
  inputEl.addEventListener('focus', () => (splitValueAt = inputEl.value.length + 1));
  inputEl.addEventListener('change', () => onChange(inputEl));
  inputEl.addEventListener('keyup', (e) => {
    if (e.key.length == 1 || ['ArrowLeft', 'ArrowRight', 'Backspace'].indexOf(e.key) != -1) onChange(inputEl);
  });
  inputEl.addEventListener('keydown', (e) => {
    if (e.key == 'ArrowDown') return focusAutocompleteItem(e, e.shiftKey ? 4 : 1);
    if (e.key == 'ArrowUp') return focusAutocompleteItem(e, e.shiftKey ? -4 : -1);
    if (e.key == 'Enter') return selectOptionOrSendMessage(e);
    if (e.key == 'Tab') return focusAutocompleteItem(e, e.shiftKey ? -1 : 1);
  });

  setValue(typeof conversation.userInput == 'undefined' ? '' : conversation.userInput);
}

function selectOption(e) {
  autocompleteIndex = parseInt(e.target.closest('a').href.replace(/.*index:/, ''), 10);
  fillin(autocompleteOptions[autocompleteIndex], {padAfter: true, replace: true});
  setTimeout(() => inputEl.focus(), 1);
}

function selectOptionOrSendMessage(e) {
  const autocompleteOpt = autocompleteOptions[autocompleteIndex];
  if (autocompleteOpt) {
    e.preventDefault();
    fillin(autocompleteOptions[autocompleteIndex], {replace: true});
    splitValueAt = inputEl.selectionStart + 1;
  }
  else if (!e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
    e.preventDefault();
    const msg = {method: 'send'};
    msg.message = inputEl.value;

    // Aliases
    msg.message = msg.message.replace(/^\/close/i, '/part');
    msg.message = msg.message.replace(/^\/j\b/i, '/join');
    msg.message = msg.message.replace(/^\/raw/i, '/quote');

    if (msg.message.length) conversation.send(msg).then(handleMessageResponse);
    if (!conversation.is('search')) setValue('');
  }
}

function setValue(val) {
  if (inputEl) inputEl.value = val;
  conversation.update({userInput: val});
}

function startAutocomplete(splitValueAt) {
  if (!inputEl) return;
  autocompleteOptions = splitValueAt > inputEl.value.length ? [] : calculateAutocompleteOptions(inputEl.value, splitValueAt, {conversation, user});
  autocompleteCategory = autocompleteOptions.length && autocompleteOptions[0].autocompleteCategory || 'none';
}

function updateValueWhenConversationChanges(conversation) {
  if (updateValueWhenConversationChanges.lock == conversation.path) return;
  updateValueWhenConversationChanges.lock = conversation.path;
  setValue(typeof conversation.userInput == 'undefined' ? '' : conversation.userInput);
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
    if (res.errors) conversation.addMessage({message: 'Could not upload file: %1', vars: [$l(extractErrorMessage(res.errors))], type: 'error'});
  });
}
</script>

<form class="chat-input" on:submit|preventDefault>
  <textarea class="is-primary-input" placeholder="{placeholder}" use:onReady></textarea>

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
