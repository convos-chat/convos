<script>
import FormActions from './form/FormActions.svelte';
import PasswordField from './form/PasswordField.svelte';
import TextField from './form/TextField.svelte';
import SidebarLoggedout from './SidebarLoggedout.svelte';
import {l} from '../js/i18n';
</script>

<SidebarLoggedout/>

<div class="next-to-sidebar is-logged-out">
  <h1>{l('Login')}</h1>
  <form class="login">
    <TextField name="email">
      <span slot="label">{l('E-mail')}</span>
    </TextField>
    <PasswordField name="password">
      <span slot="label">{l('Password')}</span>
    </PasswordField>
    <FormActions>
      <button>{l('Log in')}</button>
    </FormActions>
  </form>
</div>