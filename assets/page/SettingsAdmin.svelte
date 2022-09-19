<script>
import Button from '../components/form/Button.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import Checkbox from '../components/form/Checkbox.svelte';
import OperationStatus from '../components/OperationStatus.svelte';
import TextField from '../components/form/TextField.svelte';
import {convosApi} from '../js/Api';
import {humanReadableNumber, settings} from '../js/util';
import {l, lmd} from '../store/I18N';
import {onMount} from 'svelte';
import {videoService} from '../store/video';

export const title = 'Global settings';

const checkForUpdatesOp = convosApi.op('checkForUpdates');
const getSettingsOp = convosApi.op('getSettings');
const updateSettingsOp = convosApi.op('updateSettings');

let diskUsage = null;
let form = {};

$: latestVersion = $checkForUpdatesOp.res.body.available;
$: hasLatests = latestVersion === settings('version');

onMount(async () => {
  await getSettingsOp.perform();
  const fields = getSettingsOp.res.body;
  diskUsage = calculateDiskUsage(fields.disk_usage);
  delete fields.disk_usage;
  fields.contact = fields.contact.replace(/mailto:/, '');
  form = {...form, ...fields};
});

function calculateDiskUsage(usage) {
  if (!usage) return null;
  const blockSize = usage.block_size || 1024;

  return {
    blocks_pct: Math.ceil(usage.blocks_used / usage.blocks_total * 100),
    blocks_total: humanReadableNumber(blockSize * usage.blocks_total, 'B'),
    blocks_used: humanReadableNumber(blockSize * usage.blocks_used, 'B'),
    inodes_pct: Math.ceil(usage.inodes_used / usage.inodes_total * 100),
    inodes_total: humanReadableNumber(usage.inodes_total),
    inodes_used: humanReadableNumber(usage.inodes_used),
  };
}

function updateSettingsFromForm() {
  if (form.contact) form.contact = 'mailto:' + form.contact;
  settings('contact', form.contact);
  settings('open_to_public', form.open_to_public);
  settings('organization_name', form.organization_name);
  settings('organization_url', form.organization_url);
  videoService.fromString(form.video_service);
  updateSettingsOp.perform(form);
}
</script>

<ChatHeader>
  <h1>{$l('Global settings')}</h1>
</ChatHeader>

<main class="main">
  <form id="convos-settings" method="post" on:submit|preventDefault="{updateSettingsFromForm}">
    <h2>{$l('Convos settings')}</h2>
    <p>{@html $lmd('These settings control what users experience when they visit [%1](%1).', settings('base_url'))}</p>

    <TextField name="organization_name" bind:value="{form.organization_name}">
      <span slot="label">{$l('Organization name')}</span>
      <p class="help" slot="help">{$l('Can be changed if you want to add a touch of your organization.')}</p>
    </TextField>
    <TextField name="organization_url" bind:value="{form.organization_url}" placeholder="{$l('https://convos.chat')}">
      <span slot="label">{$l('Organization URL')}</span>
      <p class="help" slot="help">{$l('Used together with "Organization name" to add a link to your organization on the login screen.')}</p>
    </TextField>
    <TextField name="contact" bind:value="{form.contact}" placeholder="{$l('Ex: jhthorsen@cpan.org')}">
      <span slot="label">{$l('Admin email')}</span>
      <p class="help" slot="help">{$l('This email can be used by users to get in touch with the Convos admin.')}</p>
    </TextField>
    <TextField name="video_service" bind:value="{form.video_service}" placeholder="{$l('Ex: https://meet.jit.si/')}">
      <span slot="label">{$l('Video service')}</span>
      <p class="help" slot="help">{@html $lmd('This should point to a [%1](%2) instance.', 'https://meet.jit.si/', 'https://github.com/jitsi/jitsi-meet')}</p>
    </TextField>
    <Checkbox name="open_to_public" bind:value="{form.open_to_public}">
      <span slot="label">{$l('Registration is open to public')}</span>
    </Checkbox>
    <p class="help">{$l('Tick this box if you want users to be able to register without an invite URL.')}</p>

    <div class="form-actions">
      <Button icon="save" op="{updateSettingsOp}"><span>{$l('Save settings')}</span></Button>
    </div>

    <OperationStatus op="{updateSettingsOp}"/>
  </form>

  <h2>{$l('Check for updates')}</h2>
  <form id="convos-updates" method="post" on:submit|preventDefault="{() => checkForUpdatesOp.perform()}">
    {#if $checkForUpdatesOp.is('error')}
      <div class="error">{$l($checkForUpdatesOp.error())}</div>
    {:else if $checkForUpdatesOp.is('success')}
      <p>{$lmd((hasLatests ? 'You have Convos v%1, which is the latest version.' : 'Convos v%1 is available.'), latestVersion)}</p>
    {:else}
      <p>{$lmd('You currently have Convos v%1 installed.', settings('version'))}</p>
    {/if}
    <Button icon="sync-alt" op="{checkForUpdatesOp}"><span>{$l('Check for updates')}</span></Button>
  </form>

  {#if diskUsage}
    <div id="disk-usage">
      <h2>{$l('Disk usage')}</h2>
      <div class="progress">
        <div class="progress__bar" style="width:{diskUsage.blocks_pct}%;">{diskUsage.blocks_pct}%</div>
      </div>
      <p class="help">{$l('Disk usage')}: {diskUsage.blocks_used} / {diskUsage.blocks_total}</p>
       <div class="progress">
        <div class="progress__bar" style="width:{diskUsage.inodes_pct}%;">{diskUsage.inodes_pct}%</div>
      </div>
      <p class="help">{$l('Inode usage')}: {diskUsage.inodes_used} / {diskUsage.inodes_total}</p>
    </div>
  {/if}
</main>
