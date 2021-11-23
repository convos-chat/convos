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
const form = createForm();
const deleteFilesOp = api('deleteFiles');
const getFilesOp = api('getFiles');

let files = [];

$: selectedFiles = Object.keys($form).filter(v => !!$form[v]);
$: loadFiles($route);
$: afterId = calculateAfterId(getFilesOp, files);
$: prevId = $getFilesOp.res.body.prev || '';

function calculateAfterId(getFilesOp, files) {
  return getFilesOp.res.body.next && files.length ? files.slice(-1)[0].id : '';
}

function copyUrl(e) {
  const link = e.target.closest('tr').querySelector('[target="convos_files_file"]');
  const copied = copyToClipboard({value: link.href});
  if (copied) notify.showInApp(copied, {closeAfter: 3000, title: $l('File URL copied')});
}

async function deleteFiles() {
  await deleteFilesOp.perform({fid: selectedFiles.join(','), uid: user.id});
  files = files.filter(i => selectedFiles.indexOf(i.id) == -1);
  selectedFiles.forEach(id => form.set({[id]: false}));
  if (files.length == 0) loadFiles(route);
}

async function loadFiles(route) {
  const after = route.query.after || '';
  await getFilesOp.perform({after, limit: 20});
  files = getFilesOp.res.body.files || [];
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
        <th class="text-right">{$l('Delete')}</th>
      </tr>
    </thead>
    <tbody>
      {#each files as file}
        <tr>
          <td>{new Time(file.saved).getHumanDate({year: true})}</td>
          <td><Icon name="copy" on:click="{copyUrl}"/></td>
          <td><a href="{route.urlFor('/file/' + user.id + '/' + file.id)}" target="convos_files_file">{file.name}</a></td>
          <td class="text-right">{humanReadableNumber(file.size, 'B')}</td>
          <td class="text-right"><Checkbox form="{form}" name="{file.id}"/></td>
        </tr>
      {/each}
      <OperationStatusRow colspan="5" op="{getFilesOp}"><div>&nbsp;</div></OperationStatusRow>
    </tbody>
  </table>
  <div class="pagination">
    {#if prevId || $route.query.after}
      <Link href="/settings/files?after={prevId}">{$l('Previous')}</Link>
    {:else}
      <span class="disabled">{$l('Previous')}</span>
    {/if}
    {#if afterId}
      <Link href="/settings/files?after={afterId}">{$l('Next')}</Link>
    {:else}
      <span class="disabled">{$l('Next')}</span>
    {/if}
  </div>

  <div class="form-actions">
    <Button icon="trash" op="{deleteFilesOp}" on:click="{deleteFiles}" disabled="{!selectedFiles.length}"><span>{$l('Delete selected files')}</span></Button>
  </div>

  <p>
    {@html $lmd('By deleting the files, you and everyone with the link *should* lose access to the file: Aggressive caching in browsers or proxies between Convos and other users might keep the file around for some time.')}
  </p>

  <OperationStatus op="{deleteFilesOp}" success="Deleted."/>
</main>
