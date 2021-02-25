import {get, writable} from 'svelte/store';

export const formAction = (formEl, formStore) => {
  formEl.addEventListener('change', (e) => {
    const inputEl = e.target;
    if (!inputEl || !inputEl.name) return;
    const value = inputEl.type == 'checkbox' ? inputEl.checked ? inputEl.value : undefined : inputEl.value;
    formStore.set({...get(formStore), [inputEl.name]: value});
  });

  formEl.addEventListener('submit', (e) => {
    e.preventDefault();
    formStore.submit();
  });

  formStore.formEl = formEl;
  formStore.render();
};

export const makeFormStore = (defaults = {}) => {
  const formStore = writable(defaults);

  formStore.renderOnNextTick = function(fields) { setTimeout(() => this.render(fields), 1) };
  formStore.submit = function() { };

  formStore.render = function(fields) {
    if (fields) this.set({...get(this), ...fields});
    if (!this.formEl) return null;
    if (!fields) fields = get(this);

    return Object.keys(fields).map(name => {
      const inputEl = this.formEl.querySelector('[name="' + name + '"]');
      if (!inputEl || typeof fields[name] == 'undefined') return null;
      inputEl.type == 'checkbox' ? (inputEl.checked = fields[name] ? true : false)
        : (inputEl.value = fields[name]);
      if (inputEl.syncValue) inputEl.syncValue();
      return name;
    });
  };

  return formStore;
};
