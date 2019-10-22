<script>
import Link from './Link.svelte';
import {l} from '../js/i18n';
</script>

<div class="sidebar-wrapper">
  <h1 class="sidebar__logo">
    <Link href="/"><span>{l('Convos')}</span></Link>
  </h1>

  <p class="sidebar__about">{l('A multiuser chat application.')}</p>

  <nav class="sidebar__nav">
    <Link href="/login">{l('Login')}</Link>
    <Link href="/register">{l('Create account')}</Link>
    <Link href="https://convos.by/doc">{l('Documentation')}</Link>
    <Link href="https://github.com/Nordaaker/convos">{l('GitHub')}</Link>
  </nav>
</div>
