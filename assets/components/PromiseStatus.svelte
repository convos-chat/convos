<script>
import {l} from '../js/i18n';
export let promise;

let err = undefined;
let loading = false;
let res = undefined;

$: document.querySelector('body').classList[loading ? 'add' : 'remove']('is-loading');

$: if (promise) {
  promise.then(
    (r) => { loading = false; err = undefined; res = r },
    (e) => { loading = false; res = undefined; err = e },
  );
}

function extractError(err) {
  if (Array.isArray(err.errors) && err.errors.length) {
    const first = err.errors[0];
    return (first.path && first.path.match(/\w/) ? first.path.split('/').pop() + ': ' : '') + first.message;
  }
  else {
    return err.statusText || 'Unknown error.';
  }
}
</script>

{#if loading}
<div class="loading"><slot name="loading">{l('Loading...')}</slot></div>
{:else if promise && err}
<div class="error"><slot name="error">{l(extractError(err))}</slot></div>
{/if}
