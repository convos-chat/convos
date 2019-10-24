<script>
const familyToClassName = {regular: 'far', solid: 'fas'};
const randomIcons = [
  'atom',
  'award fa-solid',
  'balance-scale',
  'baseball-ball',
  'basketball-ball fa-solid',
  'bicycle',
  'bolt fa-solid',
  'book-reader',
  'candy-cane fa-solid',
  'carrot fa-solid',
  'cat',
  'chess-knight',
  'child',
  'coffee fa-solid',
  'cookie-bite fa-solid',
  'crow fa-solid',
  'dice fa-solid',
  'dog fa-solid',
  'dove',
  'feather fa-solid',
  'fish',
  'fly',
  'gem fa-solid',
  'ghost fa-solid',
  'hard-hat fa-solid',
  'hat-cowboy fa-solid',
  'hat-wizard fa-solid',
  'hiking',
  'horse fa-solid',
  'horse-head fa-solid',
  'id-badge',
  'igloo fa-solid',
  'mask fa-solid',
  'meteor fa-solid',
  'paint-brush fa-solid',
  'paw',
  'pepper-hot fa-solid',
  'pied-piper-hat fa-solid',
  'pizza-slice fa-solid',
  'portrait',
  'puzzle-piece fa-solid',
  'rainbow fa-solid',
  'redhat',
  'robot fa-solid',
  'rocket fa-solid',
  'running',
  'seedling fa-solid',
  'skating fa-solid',
  'skiing',
  'smile',
  'snowboarding',
  'snowflake fa-solid',
  'snowman fa-solid',
  'swimmer fa-solid',
  'umbrella fa-solid',
  'user-astronaut',
  'user-graduate',
  'user-ninja',
  'user-secret',
  'walking',
  'yin-yang fa-solid',
];

let className = '';
let classNames = [];

export {className as class};
export let animation = '';
export let family = '';
export let name;
export let style = '';
export let title = '';

$: {
  classNames = [familyToClassName[family] || 'fa'];
  classNames.push('fa-' + (name && name.indexOf('pick:') == 0 ? randomIcon(name) : name));
  if (animation) classNames = classNames.concat(animation.split(' ').map(a => 'fa-' + a));
  if (className) classNames = classNames.concat(className.split(' '));
}

function randomIcon(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
    hash = hash & hash;
  }

  hash = Math.abs(hash);
  return randomIcons[hash % randomIcons.length];
}
</script>

<i class="{classNames.join(' ')}" {title} on:click hidden="{!name}" style="{style}"/>
