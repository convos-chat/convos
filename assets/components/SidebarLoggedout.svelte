<script>
import Link from './Link.svelte';
import {l} from '../js/i18n';
</script>

<div class="sidebar-wrapper">
  <div class="sidebar is-logged-out">
    <h1 class="sidebar__logo">
      <Link href="/"><span>{l('Convos')}</span></Link>
    </h1>
    <p class="sidebar__about">A multiuser chat application.</p>

    <nav class="sidebar__nav">
      <Link href="/">{l('Login')}</Link>
      <Link href="/register">{l('Create account')}</Link>
      <Link href="/doc">{l('Documentation')}</Link>
      <Link href="https://github.com/Nordaaker/convos">{l('GitHub')}</Link>
    </nav>
  </div>
</div>