<script>
import Icon from '../components/Icon.svelte';
import {calculateAutocompleteOptions, fillIn as _fillIn} from '../js/autocomplete';
import {chatHelper, videoWindow} from '../js/chatHelpers';
import {extractErrorMessage, is} from '../js/util';
import {fly} from 'svelte/transition';
import {generateWriteable, viewport} from '../store/writable';
import {getContext} from 'svelte';
import {l} from '../store/I18N';
import {normalizeCommand} from '../js/commands';

export const uploader = uploadFiles;
export let conversation;

let autocompleteIndex = 0;
let autocompleteOptions = [];
let autocompleteCategory = 'none';
let chatMenuTransition = {y: -10, duration: 200};
let inputEl;
let inputMirror;
let splitValueAt = 0;

const api = getContext('api');
const user = getContext('user');
const activeChatMenu = generateWriteable('activeChatMenu');

$: connection = user.findConversation({connection_id: conversation.connection_id});
$: conversation && ($activeChatMenu = '');
$: nick = connection && connection.nick;
$: placeholder = conversation.is('search') ? $l('What are you looking for?') : connection && connection.is('unreachable') ? $l('Connecting...') : $l('What is on your mind %1?', nick);
$: sendIcon = conversation.is('search') ? 'search' : 'paper-plane';
$: onVideoLinkClick = chatHelper('onVideoLinkClick', {conversation, user});
$: startAutocomplete(splitValueAt);
$: updateValueWhenConversationChanges(conversation);

export function fillIn(str, params) {
  const {before, middle, after} = _fillIn(str, {...params, cursorPos: inputEl.selectionStart, value: inputEl.value});
  setValue(before + middle + after);
  inputEl.selectionStart = inputEl.selectionEnd = (before + middle).length;
}

export function focus() {
  if (inputEl) inputEl.focus();
}

function focusAutocompleteItem(e, moveBy) {
  if (!autocompleteOptions.length) return;
  e.preventDefault();
  autocompleteIndex += moveBy;
  if (autocompleteIndex < 0) autocompleteIndex = autocompleteOptions.length - 1;
  if (autocompleteIndex >= autocompleteOptions.length) autocompleteIndex = 0;
  fillIn(autocompleteOptions[autocompleteIndex], {replace: true});
}

function handleMessageResponse(msg) {
  if (!msg.conversation_id && conversation.conversation_id) msg.conversation_id = conversation.conversation_id;
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
  inputEl.addEventListener('input', renderInputHeight);
  inputEl.addEventListener('keyup', (e) => {
    if (e.key.length == 1 || ['ArrowLeft', 'ArrowRight', 'Backspace'].indexOf(e.key) != -1) onChange(inputEl);
  });
  inputEl.addEventListener('keydown', (e) => {
    if (e.key == 'ArrowDown') return focusAutocompleteItem(e, e.shiftKey ? 4 : 1);
    if (e.key == 'ArrowUp') return focusAutocompleteItem(e, e.shiftKey ? -4 : -1);
    if (e.key == 'Enter') return selectOptionOrSendMessage(e);
    if (e.key == 'Tab') return focusAutocompleteItem(e, e.shiftKey ? -1 : 1);
  });

  setValue(is.undefined(conversation.userInput) ? '' : conversation.userInput);
}

function renderInputHeight() {
  if (!inputMirror.maxHeight) inputMirror.maxHeight = inputMirror.parentNode.offsetHeight;
  inputMirror.value = inputEl.value;
  inputMirror.style.width = inputEl.offsetWidth + 'px';
  inputEl.style.height = (inputMirror.maxHeight > inputMirror.scrollHeight ? inputMirror.scrollHeight : inputMirror.maxHeight) + 'px';
}

function selectOption(e) {
  autocompleteIndex = parseInt(e.target.closest('a').href.replace(/.*index:/, ''), 10);
  fillIn(autocompleteOptions[autocompleteIndex], {padAfter: true, replace: true});
  setTimeout(() => inputEl.focus(), 1);
}

function selectOptionOrSendMessage(e) {
  const autocompleteOpt = autocompleteOptions[autocompleteIndex];
  if (autocompleteOpt) {
    e.preventDefault();
    fillIn(autocompleteOptions[autocompleteIndex], {replace: true});
    splitValueAt = inputEl.selectionStart + 1;
  }
  else if (!e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
    e.preventDefault();
    const msg = {method: 'send'};
    msg.message = normalizeCommand(inputEl.value);
    if (msg.message.length) conversation.send(msg, handleMessageResponse);
    if (!conversation.is('search')) setValue('');
    setTimeout(renderInputHeight, 10);
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
  setValue(is.undefined(conversation.userInput) ? '' : conversation.userInput);
}

function uploadFiles(e) {
  const files = (e.target && e.target.files) || (e.dataTransfer && e.dataTransfer.files);
  if (!files || !files.length) return;
  if (files.length > 1) return conversation.addMessages({message: 'Cannot upload more than one file.', type: 'error'});

  const formData = new FormData();
  formData.append('file', files[0]);
  api('uploadFile').perform({formData}).then(op => {
    const res = op.res.body;
    if (res.files && res.files.length) return fillIn(res.files[0].url, {append: true});
    if (res.errors) conversation.addMessages({message: 'Could not upload file: %1', vars: [$l(extractErrorMessage(res.errors))], type: 'error'});
  });
}
</script>

<form class="chat-input" on:submit|preventDefault>
  <input type="file" id="upload_files" name="upload_files" class="non-interactive" on:change="{uploadFiles}"/>
  <textarea class="non-interactive" placeholder="{placeholder}" bind:this="{inputMirror}"></textarea>
  <textarea class="is-primary-input" placeholder="{placeholder}" use:onReady></textarea>

  {#if $viewport.nColumns > 1 && $conversation.is('conversation')}
    <label for="upload_files" class="btn-hallow upload"><Icon name="cloud-upload-alt"/></label>
    {#if $user.videoService}
      <a href="#action:video" on:click="{onVideoLinkClick}" class="btn-hallow has-tooltip" tooltip="{$l('Start a video conference')}"><Icon name="{$videoWindow ? 'video-slash' : 'video'}"/></a>
    {/if}
  {/if}

  {#if $viewport.nColumns == 1 && conversation.is('conversation')}
    <a href="#actions" class="btn-hallow" class:is-active="{$activeChatMenu == 'actions'}" on:click="{activeChatMenu.toggle}">
      <Icon name="plus-circle"/>
      <Icon name="times"/>
    </a>
  {/if}

  <button type="buttton" on:click="{selectOptionOrSendMessage}" class="btn-hallow chat-input__send"><Icon name="{sendIcon}"/></button>

  {#if $activeChatMenu == 'actions' && conversation.is('conversation')}
    <div class="chat-input_menu for-actions" transition:fly="{chatMenuTransition}" on:click="{activeChatMenu.toggle}">
      <a href="#action:video" on:click="{onVideoLinkClick}">
        <Icon name="{$videoWindow ? 'video-slash' : 'video'}"/>
        {$l('Start a video conference')}
      </a>
      <label for="upload_files">
        <Icon name="cloud-upload-alt"/>
        {$l('Attach a file')}
      </label>
    </div>
  {:else if autocompleteOptions.length}
    <div class="chat-input_menu for-{autocompleteCategory}" transition:fly="{chatMenuTransition}">
      {#each autocompleteOptions as opt, i}
        <a href="#index:{i}" class:has-focus="{i == autocompleteIndex}" on:click|preventDefault="{selectOption}" tabindex="-1">{@html opt.text || opt.val}</a>
      {/each}
    </div>
  {/if}
</form>
