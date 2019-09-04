<script>
export let className = '';
export let family = '';
export let name;
export let title = '';

const familyToClassName = {
  regular: 'far',
  solid: 'fas',
};

let classNames = [];

$: {
  classNames = [familyToClassName[family] || 'fa'];
  classNames.push('fa-' + (name || 'default'));
  if (className) classNames.push(className);
}
</script>

<i class="{classNames.join(' ')}" {title} on:click hidden="{!name}"/>
