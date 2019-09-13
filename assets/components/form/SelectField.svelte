<script>
import {closestEl, uuidv4} from '../../js/util';
import {onMount, tick} from 'svelte';

export let className = '';
export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let options = [];
export let placeholder = '';
export let readonly = false;
export let value = '';

const preventKeys = ['ArrowDown', 'ArrowUp', 'Enter'];

let activeIndex = 0;
let hiddenEl;
let humanEl;
let typed = '';
let visible = false;
let wrapperEl;

$: classNames = ['select-field', 'text-field', className].filter(c => c.length).concat(visible ? 'is-open' : 'is-closed');
$: visibleOptions = filterOptions(options, typed);
$: if (visible == true) activeIndex = 0;
$: if (visible == false) typed = '';
$: if (hiddenEl && hiddenEl.value !== value) hiddenEl.value = value;

$: if (humanEl && !humanEl.value && humanEl != document.activeElement) {
  const found = options.find(opt => opt[0] == hiddenEl.value);
  if (found) humanEl.value = found[1] || found[0];
}

function filterOptions(options, needle) {
  let re = new RegExp('(?:^|\\s|-)' + needle, 'i'); // TODO: needle need to be safe string
  let found = [];
  if (!found.length) found = options.filter(opt => opt[0] == needle);
  if (!found.length) found = options.filter(opt => opt[0].match(re));
  return found.concat(options.filter(opt => opt.length > 1 && found.indexOf(opt) != -1 && opt[1].match(re)));
}

function keydown(e) {
  if (preventKeys.indexOf(e.key) != -1) e.preventDefault();

  if (e.key == 'Tab') {
    if (visible) selectOption(e);
    return;
  }

  if (!visible) {
    visible = true;
    return;
  }

  if (e.key == 'ArrowDown') activeIndex++;
  if (e.key == 'ArrowUp') activeIndex--;
  if (e.key == 'Enter') selectOption(e);
  if (activeIndex >= options.length) activeIndex = 0;
  if (activeIndex < 0) activeIndex = options.length - 1;
}

function keyup(e) {
  if (e.key.length == 1 || e.key == 'Backspace') typed = humanEl.value;
}

async function selectOption(e) {
  let opt;
  if (e.type == 'keydown') {
    opt = visibleOptions.length ? visibleOptions[activeIndex] : [];
  }
  else {
    const needle = e.target.href.replace(/^.*?#\d+:/, '');
    opt = visibleOptions.filter(opt => opt[0] == needle)[0] || [];
  }

  if (!opt.length) opt = [''];
  value = opt[0];
  humanEl.value = opt.length > 1 ? opt[1] : opt[0];
  await tick();
  humanEl.setSelectionRange(0, 9999);
  visible = false;
}

function toggle() {
  visible = !visible;
}

onMount(() => {
  humanEl.addEventListener('blur', () => setTimeout(() => { visible = false }, 100));
  value = hiddenEl.value;
});
</script>

<div class="{classNames.join(' ')}" hidden="{hidden}" bind:this="{wrapperEl}" on:click|preventDefault="{toggle}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="hidden" {name} bind:this="{hiddenEl}" bind:value on:keydown="{keydown}"/>
  <input type="text" {placeholder} {id} {readonly} autocomplete="off"
    bind:this="{humanEl}"
    on:keydown="{keydown}"
    on:keyup="{keyup}"/>
  <div class="select-field__options">
    {#each visibleOptions as opt, i}
      <a href="#{i}:{opt[0]}"
        class:is-active="{i == activeIndex}"
        on:click="{selectOption}"
        on:mouseover="{() => { activeIndex = i }}"
        tabindex="-1">{opt.length > 1 ? opt[1] : opt[0]}</a>
    {/each}
  </div>
</div>
