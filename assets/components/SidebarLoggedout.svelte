<script>
import Link from './Link.svelte';
import {l} from '../js/i18n';
</script>

<div class="sidebar-left">
  <h1><Link href="/"><span>{l('Convos')}</span></Link></h1>
  <p>{l('A multiuser chat application.')}</p>

  <nav class="sidebar-left__nav">
    <Link href="/login">{l('Login')}</Link>
    <Link href="/register">{l('Create account')}</Link>
    <Link href="https://convos.by/doc">{l('Documentation')}</Link>
    <Link href="https://github.com/Nordaaker/convos">{l('GitHub')}</Link>
  </nav>
</div>
