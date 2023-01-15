<script>
import CommandHistory from '../store/CommandHistory';
import Icon from '../components/Icon.svelte';
import now from 'lodash/now';
import {convosApi} from '../js/Api';
import {calculateAutocompleteOptions, fillIn as _fillIn} from '../js/autocomplete';
import {extractErrorMessage, is, nbsp} from '../js/util';
import {fly} from 'svelte/transition';
import {getContext} from 'svelte';
import {getUserInputStore} from '../store/localstorage';
import {l} from '../store/I18N';
import {normalizeCommand} from '../js/commands';
import {videoService, videoWindow} from '../store/video';

export const uploader = uploadFiles;
export let uploadProgress = 0;
export let conversation;

let activeChatMenu = '';
let autocompleteIndex = 0;
let autocompleteOptions = [];
let autocompleteCategory = 'none';
let chatMenuTransition = {y: -10, duration: 200};
let inputEl;
let inputMirror;
let splitValueAt = 0;

const user = getContext('user');
const commandHistory = new CommandHistory();

$: if (conversation) activeChatMenu = '';
$: connection = user.findConversation({connection_id: conversation.connection_id});
$: nick = connection && connection.nick;
$: placeholder = conversation.is('search') ? $l('What are you looking for?') : connection && connection.is('unreachable') ? $l('Connecting...') : $l('What is on your mind %1?', nick);
$: sendIcon = conversation.is('search') ? 'search' : 'paper-plane';
$: tooltip = conversation.is('search') ? $l('Search') : $l('Send');
$: userInput = getUserInputStore(conversation.id);
$: videoUrl = videoService.conversationToInternalUrl(conversation);
$: commandHistory.update({conversation: $conversation});
$: startAutocomplete(splitValueAt);
$: updateValueWhenConversationChanges(conversation);

function activeChatMenuToggle(e) {
  const a = e.target.closest('a');
  const set = !a || activeChatMenu ? '' : a.href.replace(/.*#/, '');
  setTimeout(() => { activeChatMenu = set }, 1);
}

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
  $userInput = inputEl.value;
  if (!inputEl.value.length) commandHistory.update({index: -1});
}

function onReady(el) {
  inputEl = el;
  inputEl.addEventListener('focus', () => (splitValueAt = inputEl.value.length + 1));
  inputEl.addEventListener('change', () => onChange(inputEl));
  inputEl.addEventListener('input', renderInputHeight);
  inputEl.addEventListener('keyup', (e) => {
    if (e.key.length === 1 || ['ArrowLeft', 'ArrowRight', 'Backspace'].indexOf(e.key) !== -1) onChange(inputEl);
  });
  inputEl.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' && commandHistory.render(e, -1)) return;
    if (e.key === 'ArrowUp' && commandHistory.render(e, 1)) return;
    if (e.key === 'ArrowDown') return focusAutocompleteItem(e, e.shiftKey ? 4 : 1);
    if (e.key === 'ArrowUp') return focusAutocompleteItem(e, e.shiftKey ? -4 : -1);
    if (e.key === 'Enter') return selectOptionOrSendMessage(e);
    if (e.key === 'Tab') return focusAutocompleteItem(e, e.shiftKey ? -1 : 1);
  });

  commandHistory.attach(inputEl);
  setValue($userInput);
}

function onVideoLinkClick(e) {
  e.preventDefault();
  videoWindow.open(videoUrl, {nick: conversation.participants.me().nick});
  const alreadySent = conversation.messages.toArray().slice(-20).find(msg => msg.message.indexOf(videoUrl) !== -1);
  if (alreadySent && alreadySent.ts.toEpoch() > now() - 600) return;
  conversation.send({method: 'send', message: videoService.conversationToExternalUrl(conversation)});
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
  setTimeout(() => { onChange(inputEl); inputEl.focus() }, 1);
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
    commandHistory.add(msg.message);
    if (!conversation.is('search')) setValue('');
    setTimeout(renderInputHeight, 10);
  }
}

function setValue(val) {
  if (inputEl) inputEl.value = val;
  $userInput = val;
}

function startAutocomplete(splitValueAt) {
  if (!inputEl) return;
  autocompleteOptions = splitValueAt > inputEl.value.length ? [] : calculateAutocompleteOptions(inputEl.value, splitValueAt, {conversation, user});
  autocompleteCategory = autocompleteOptions.length && autocompleteOptions[0].autocompleteCategory || 'none';
}

function updateValueWhenConversationChanges(conversation) {
  if (updateValueWhenConversationChanges.lock === conversation.path) return;
  updateValueWhenConversationChanges.lock = conversation.path;
  setValue($userInput);
}

function uploadFiles(e) {
  const files = (e.target && e.target.files) || (e.dataTransfer && e.dataTransfer.files);
  if (!files || !files.length) return;
  if (files.length > 1) return conversation.addMessages({message: 'Cannot upload more than one file.', type: 'error'});

  const formData = new FormData();
  formData.append('file', files[0]);
  uploadFiles.file = files[0];

  const op = convosApi.op('uploadFile');
  op.on('progress', e => {
    if (uploadProgress < 100) uploadProgress = parseInt(100 * (e.total ? e.loaded / e.total : 0.02), 10);
    if (uploadProgress >= 100) uploadProgress = 0;
  });

  uploadProgress = 1;
  op.perform({formData}).then(op => {
    const res = op.res.body;
    uploadProgress = 0;
    if (res.files && res.files.length) return fillIn(res.files[0].url, {append: true});
    if (res.errors) conversation.addMessages({message: 'Could not upload file: %1', vars: [$l(extractErrorMessage(res.errors))], type: 'error'});
  });
}
</script>

<svelte:window on:click="{() => {activeChatMenu = ''}}"/>

<form class="chat-input" on:submit|preventDefault>
  <input type="file" id="upload_files" name="upload_files" class="non-interactive" on:change="{uploadFiles}"/>
  <textarea class="non-interactive" placeholder="{placeholder}" bind:this="{inputMirror}"></textarea>
  <textarea class="is-primary-input" placeholder="{placeholder}" use:onReady></textarea>

  {#if conversation.is('conversation')}
    <a href="#actions" class="btn-hallow can-toggle" class:is-active="{activeChatMenu === 'actions'}" on:click|preventDefault="{activeChatMenuToggle}">
      <Icon name="plus-circle"/><Icon name="times"/>
    </a>
  {/if}

  <button type="buttton" on:click="{selectOptionOrSendMessage}" class="btn-hallow has-tooltip chat-input__send">
    <Icon name="{sendIcon}"/>
    <span class="tooltip is-above is-left">{nbsp($l(tooltip))}</span>
  </button>

  {#if activeChatMenu === 'actions' && conversation.is('conversation')}
    <div class="chat-input_menu for-actions" transition:fly="{chatMenuTransition}">
      {#if videoUrl}
        <a href="{videoUrl}" on:click="{onVideoLinkClick}">
          <Icon name="video"/> {$l('Start a video conference')}
        </a>
      {/if}
      <label for="upload_files">
        <Icon name="cloud-upload-alt"/>
        {$l('Attach a file')}
      </label>
    </div>
  {:else if autocompleteOptions.length}
    <div class="chat-input_menu for-{autocompleteCategory}" transition:fly="{chatMenuTransition}">
      {#each autocompleteOptions as opt, i}
        <a href="#index:{i}" class:has-focus="{i === autocompleteIndex}" on:click|preventDefault="{selectOption}" tabindex="-1">{@html opt.text || opt.val}</a>
      {/each}
    </div>
  {/if}
</form>
