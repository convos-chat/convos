<script>
export let animation = '';
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
  if (animation) classNames = classNames.concat(animation.split(' ').map(a => 'fa-' + a));
  if (className) classNames = classNames.concat(className.split(' '));
}
</script>

<i class="{classNames.join(' ')}" {title} on:click hidden="{!name}"/>
