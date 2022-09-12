<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatusRow from '../components/OperationStatusRow.svelte';
import Time from '../js/Time.js';
import {convosApi} from '../js/Api';
import {copyToClipboard, humanReadableNumber} from '../js/util';
import {getContext} from 'svelte';
import {l, lmd} from '../store/I18N.js';
import {notify} from '../js/Notify';
import {route} from '../store/Route';

const deleteFilesOp = convosApi.op('deleteFiles');
const getFilesOp = convosApi.op('getFiles');
const user = getContext('user');

let allSelected = false;
let noneSelected = true;
let files = [];
let nextId = '';
let prevId = '';

$: loadFiles($route);
$: toggleSelected(allSelected);

function copyUrl(e) {
  const link = e.target.closest('tr').querySelector('[target="convos_files_file"]');
  const copied = copyToClipboard({value: link.href});
  if (copied) notify.showInApp(copied, {closeAfter: 3000, title: $l('File URL copied')});
}

async function deleteFiles() {
  const selected = files.filter(file => file.selected);
  await deleteFilesOp.perform({fid: selected.map(file => file.id).join(','), uid: user.id});
  files = files.filter(file => !file.selected);
  allSelected = false;
  calculateNoneSelected();
  if (files.length == 0) loadFiles(route);
}

async function loadFiles(route) {
  const after = route.query.after || '';
  await getFilesOp.perform({after, limit: 20});
  files = getFilesOp.res.body.files || [];
  allSelected = false;
  calculateNoneSelected();

  if (files.length || !after) {
    nextId = $getFilesOp.res.body.next && files.slice(-1)[0].id || '';
    prevId = $getFilesOp.res.body.prev || '';
  }
}

function calculateNoneSelected() {
  noneSelected = !files.find(file => file.selected);
}

function toggleSelected(allSelected) {
  files = files.map(file => { file.selected = allSelected; return file });
}
</script>

<ChatHeader>
  <h1>{$l('Files')}</h1>
</ChatHeader>

<main class="main">
  <form method="post" on:change="{calculateNoneSelected}" on:submit|preventDefault>
    <table>
      <thead>
        <tr>
          <th>{$l('Uploaded')}</th>
          <th>&nbsp;</th>
          <th>{$l('Name')}</th>
          <th class="text-right">{$l('Size')}</th>
          <th class="text-right"><Checkbox bind:value="{allSelected}"/></th>
        </tr>
      </thead>
      <tbody>
        {#each files as file}
          <tr>
            <td>{new Time(file.saved).getHumanDate({year: true})}</td>
            <td><Icon name="copy" on:click="{copyUrl}"/></td>
            <td><a href="{route.urlFor('/file/' + user.id + '/' + file.id)}" target="convos_files_file">{file.name}</a></td>
            <td class="text-right">{humanReadableNumber(file.size, 'B')}</td>
            <td class="text-right"><Checkbox name="{file.id}" bind:value="{file.selected}"/></td>
          </tr>
        {/each}
        {#if files.length == 0}
          <tr>
            <td colspan="5">{$l('No files.')}</td>
          </tr>
        {/if}
        <OperationStatusRow colspan="5" op="{deleteFilesOp}"/>
        {#if !$deleteFilesOp.is('loading')}
          <OperationStatusRow colspan="5" op="{getFilesOp}"><div>&nbsp;</div></OperationStatusRow>
        {/if}
      </tbody>
    </table>
    <div class="pagination">
      {#if prevId || $route.query.after}
        <Link href="/settings/files?after={prevId}">{$l('Previous')}</Link>
      {:else}
        <span class="disabled">{$l('Previous')}</span>
      {/if}
      {#if nextId}
        <Link href="/settings/files?after={nextId}">{$l('Next')}</Link>
      {:else}
        <span class="disabled">{$l('Next')}</span>
      {/if}
    </div>

    <div class="form-actions">
      <Button icon="trash" op="{deleteFilesOp}" on:click="{deleteFiles}" disabled="{noneSelected}"><span>{$l('Delete selected files')}</span></Button>
    </div>

    {#if files.length || $route.query.after}
      <p>
        {@html $lmd('By deleting the files, you and everyone with the link *should* lose access to the file: Aggressive caching in browsers or proxies between Convos and other users might keep the file around for some time.')}
      </p>
    {/if}
  </form>
</main>
