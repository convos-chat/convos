<script>
import escapeRegExp from 'lodash/escapeRegExp';
import {closestEl, uuidv4} from '../../js/util';

let activeIndex = 0;
let humanEl;
let open = false;
let typed = '';
let visibleOptions = [];

export let hidden = false;
export let name = '';
export let id = name ? 'form_' + name : uuidv4();
export let options; // [["value", "label"], ...]
export let placeholder = '';
export let readonly = false;
export let value;

const preventKeys = ['ArrowDown', 'ArrowUp', 'Enter'];

$: calculateVisibleOptions(options, typed);
$: if (humanEl) renderHuman(value);
$: if (open === false) typed = '';

$: if (humanEl && !humanEl.value && humanEl !== document.activeElement) {
  const found = options.find(opt => opt[0] === value);
  if (found) humanEl.value = found[1] || found[0];
}

function blur() {
  setTimeout(() => document.activeElement.closest('.select-field__option') || (open = false), 100);
  renderHuman(value);
}

function calculateVisibleOptions(options, needle) {
  let re = new RegExp('(?:^|\\s|-)' + escapeRegExp(needle), 'i'); // TODO: needle need to be safe string

  // Match by value exact
  let found = options.filter(opt => String(opt[0]) === needle);

  // Match by value sloppy
  if (!found.length) found = options.filter(opt => opt[0].match(re));

  // Append other options by text, that has not already been added
  for (let i = 0; i < options.length; i++) {
    const opt = options[i];
    if (opt.length > 1 && found.indexOf(opt) === -1 && opt[1].match(re)) {
      found.push(opt);
    }
  }

  activeIndex = 0;
  visibleOptions = found;
}

function keydown(e) {
  if (preventKeys.indexOf(e.key) !== -1) e.preventDefault();

  if (e.key === 'Tab') {
    if (open) selectOption(e);
    return;
  }

  if (!open) return toggle(e);
  if (e.key === 'ArrowDown') activeIndex++;
  if (e.key === 'ArrowUp') activeIndex--;
  if (e.key === 'Enter') selectOption(e);
  if (activeIndex >= options.length) activeIndex = 0;
  if (activeIndex < 0) activeIndex = options.length - 1;
}

function keyup(e) {
  if (e.key.length === 1 || e.key === 'Backspace') typed = humanEl.value;
}

function selectOption(e) {
  let opt;
  if (e.type === 'keydown') {
    opt = visibleOptions.length && visibleOptions[activeIndex] || options.filter(o => o[0] === value)[0];
  }
  else {
    const needle = closestEl(e.target, '.select-field__option').href.replace(/^.*?#\d+:/, '');
    opt = visibleOptions.filter(opt => String(opt[0]) === needle)[0] || [];
  }

  if (!opt || !opt.length) opt = [''];
  value = opt[0];
  open = false;
}

function renderHuman(needle) {
  const opt = visibleOptions.filter(opt => String(opt[0]) === needle)[0] || [];
  humanEl.value = opt.length > 1 ? opt[1] : opt.length ? opt[0] : needle;
}

function toggle(e) {
  if (readonly) return;
  const optionEl = e && e.target && closestEl(e.target, '.select-field__option');

  if (!open) {
    activeIndex = visibleOptions.map(o => o[0]).indexOf(value);
    humanEl.setSelectionRange(0, 9999);
  }

  return optionEl ? selectOption(e) : (open = !open);
}
</script>

<div class="select-field text-field" class:is-open="{open}" class:is-readonly="{readonly}" hidden="{hidden}">
  <label for="{id}"><slot name="label">Label</slot></label>
  <input type="hidden" name="{name}" bind:value="{value}" on:keydown="{keydown}"/>
  <input type="text"
    id="{id}"
    autocomplete="off"
    placeholder="{placeholder}"
    readonly="{readonly}"
    bind:this="{humanEl}"
    on:blur="{blur}"
    on:keydown="{keydown}"
    on:keyup="{keyup}"
    on:click|preventDefault="{toggle}">
  <div class="select-field__options">
    {#each visibleOptions as opt, i}
      <a href="#{i}:{opt[0]}" class="select-field__option" class:is-active="{i === activeIndex}" tabindex="-1"
        on:click|preventDefault="{toggle}"
        on:focus="{() => { activeIndex = i }}"
        on:mouseover="{() => { activeIndex = i }}">{opt.length > 1 ? opt[1] : opt[0]}</a>
    {/each}
  </div>
</div>
