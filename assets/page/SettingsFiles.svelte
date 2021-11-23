<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import Icon from '../components/Icon.svelte';
import Link from '../components/Link.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import OperationStatusRow from '../components/OperationStatusRow.svelte';
import Time from '../js/Time.js';
import {copyToClipboard, humanReadableNumber} from '../js/util';
import {createForm} from '../store/form';
import {getContext} from 'svelte';
import {l, lmd} from '../store/I18N.js';
import {notify} from '../js/Notify';
import {route} from '../store/Route';

const api = getContext('api');
const user = getContext('user');
const deleteFilesOp = api('deleteFiles');
const getFilesOp = api('getFiles');
const form = createForm();

let files = [];
let nextId = '';
let prevId = '';

$: loadFiles($route);
$: toggleAll($form);
$: selectedFiles = formFileIds($form).filter(name => !!$form[name]);

function formFileIds($form) {
  return Object.keys($form).filter(name => name != 'ALL_SELECTED');
}

function copyUrl(e) {
  const link = e.target.closest('tr').querySelector('[target="convos_files_file"]');
  const copied = copyToClipboard({value: link.href});
  if (copied) notify.showInApp(copied, {closeAfter: 3000, title: $l('File URL copied')});
}

async function deleteFiles() {
  await deleteFilesOp.perform({fid: selectedFiles.join(','), uid: user.id});
  form.remove(selectedFiles);
  form.set({ALL_SELECTED: (toggleAll.selected = false)});
  files = files.filter(i => selectedFiles.indexOf(i.id) == -1);
  if (files.length == 0) loadFiles(route);
}

async function loadFiles(route) {
  const after = route.query.after || '';
  await getFilesOp.perform({after, limit: 20});
  form.remove(formFileIds(form.get()));

  files = getFilesOp.res.body.files || [];
  if (files.length || !after) {
    nextId = $getFilesOp.res.body.next && files.slice(-1)[0].id || '';
    prevId = $getFilesOp.res.body.prev || '';
  }

  form.set({ALL_SELECTED: (toggleAll.selected = false)}); // Uppercase "ALL_SELECTED" should never clash with file.fid
}

function toggleAll(data) {
  if (toggleAll.selected == data.ALL_SELECTED) return form.set({ALL_SELECTED: (toggleAll.selected = false)});
  toggleAll.selected = form.get('ALL_SELECTED');
  const vals = {};
  formFileIds(form.get()).forEach(k => (vals[k] = toggleAll.selected));
  form.set(vals);
}
</script>

<ChatHeader>
  <h1>{$l('Files')}</h1>
</ChatHeader>

<main class="main">
  <table>
    <thead>
      <tr>
        <th>{$l('Uploaded')}</th>
        <th>&nbsp;</th>
        <th>{$l('Name')}</th>
        <th class="text-right">{$l('Size')}</th>
        <th class="text-right"><Checkbox form="{form}" name="ALL_SELECTED"/></th>
      </tr>
    </thead>
    <tbody>
      {#each files as file}
        <tr>
          <td>{new Time(file.saved).getHumanDate({year: true})}</td>
          <td><Icon name="copy" on:click="{copyUrl}"/></td>
          <td><a href="{route.urlFor('/file/' + user.id + '/' + file.id)}" target="convos_files_file">{file.name}</a></td>
          <td class="text-right">{humanReadableNumber(file.size, 'B')}</td>
          <td class="text-right"><Checkbox form="{form}" id="form_{file.id}" name="{file.id}"/></td>
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
    <Button icon="trash" op="{deleteFilesOp}" on:click="{deleteFiles}" disabled="{!selectedFiles.length}"><span>{$l('Delete selected files')}</span></Button>
  </div>

  {#if files.length || $route.query.after}
    <p>
      {@html $lmd('By deleting the files, you and everyone with the link *should* lose access to the file: Aggressive caching in browsers or proxies between Convos and other users might keep the file around for some time.')}
    </p>
  {/if}
</main>
