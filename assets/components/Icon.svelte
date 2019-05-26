<script>
export let className;
export let family = '';
export let name;

const familyToClassName = {
  regular: 'far',
  solid: 'fas',
}

let classNames = [];

$: {
  classNames = [familyToClassName[family] || 'fa'];
  classNames.push(name ? 'fa-' + name : 'hide');
  if (className) classNames.push(className);
}
</script>

<i class="{classNames.join(' ')}" on:click/>