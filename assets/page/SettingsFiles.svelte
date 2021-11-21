<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import Icon from '../components/Icon.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import OperationStatusRow from '../components/OperationStatusRow.svelte';
import Time from '../js/Time.js';
import {copyToClipboard} from '../js/util';
import {createForm} from '../store/form';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../store/I18N.js';
import {notify} from '../js/Notify';
import {route} from '../store/Route';

const api = getContext('api');
const user = getContext('user');
const deleteFilesOp = api('deleteFiles');
const getFilesOp = api('getFiles');
const form = createForm();

let files = [];

$: selectedFiles = Object.keys($form).filter(v => !!$form[v]);

onMount(async () => {
  await getFilesOp.perform();
  files = getFilesOp.res.body.files || [];
});

function copyUrl(e) {
  const link = e.target.closest('tr').querySelector('[target="convos_files_file"]');
  const copied = copyToClipboard({value: link.href});
  if (copied) notify.showInApp(copied, {closeAfter: 3000, title: $l('File URL copied')});
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
        <th>{$l('Delete')}</th>
      </tr>
    </thead>
    <tbody>
      <OperationStatusRow op="{getFilesOp}"/>
      {#each files as file}
        <tr>
          <td>{new Time(file.saved).getHumanDate({year: true})}</td>
          <td><Icon name="copy" on:click="{copyUrl}"/></td>
          <td><a href="{route.urlFor('/file/' + user.uid + '/' + file.id)}" target="convos_files_file">{file.filename}</a></td>
          <td><Checkbox form="{form}" name="{file.id}"/></td>
        </tr>
      {/each}
    </tbody>
  </table>

  <div class="form-actions">
    <Button icon="trash" op="{deleteFilesOp}" on:click="{deleteFilesOp.perform({ids: selectedFiles})}" disabled="{!selectedFiles.length}"><span>{$l('Delete selected files')}</span></Button>
  </div>

  <p>
    {@html $lmd('By deleting the files, you and everyone with the link *should* loose access to the file: Aggressive caching in browsers or proxies between Convos and other users might keep the file around for some time.')}
  </p>

  <OperationStatus op="{deleteFilesOp}" success="Deleted."/>
</main>
