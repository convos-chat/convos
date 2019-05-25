<script>
import SidebarChat from '../components/SidebarChat.svelte';
import {getUser} from '../store/user';
import {getContext, onMount} from 'svelte';

const api = getContext('api');
onMount(() => getUser(api));
</script>

<SidebarChat/>

<main class="chat next-to-sidebar">
  <!-- TODO -->
</main>