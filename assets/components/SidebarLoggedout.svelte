<script>
import Link from './Link.svelte';
import {getContext} from 'svelte';
import {l, lmd} from '../js/i18n';

const settings = getContext('settings');
</script>

<div class="sidebar-left">
  <h1>
    <Link href="/"><span>{l('Convos')}</span></Link>
    {#if settings.organization_name != 'Convos'}
      {#if settings.organization_url != 'https://convos.by'}
        <small class="subtitle">{@html lmd('for [%1](%1)', settings.organization_name)}</small>
      {:else}
        <small class="subtitle">{l('for %1', settings.organization_name)}</small>
      {/if}
    {/if}
  </h1>

  <p>{l('A multiuser chat application.')}</p>

  <nav class="sidebar-left__nav">
    <Link href="/login">{l('Login')}</Link>
    <Link href="/register">{l('Create account')}</Link>
    <Link href="https://convos.by/doc">{l('Documentation')}</Link>
    <Link href="https://github.com/Nordaaker/convos">{l('GitHub')}</Link>
  </nav>
</div>
