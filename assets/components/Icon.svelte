<script>
const familyToClassName = {regular: 'far', solid: 'fas'};
const randomIcons = [
  'ankh',
  'atom',
  'award',
  'balance-scale',
  'baseball-ball',
  'basketball-ball',
  'bicycle',
  'bolt',
  'book-reader',
  'candy-cane',
  'carrot',
  'cat',
  'chess-knight',
  'child',
  'coffee',
  'cookie-bite',
  'crow',
  'dice',
  'dog',
  'dove',
  'feather',
  'fish',
  'fly',
  'gem',
  'ghost',
  'hard-hat',
  'hat-cowboy',
  'hat-wizard',
  'hiking',
  'horse',
  'horse-head',
  'id-badge',
  'igloo',
  'mask',
  'meteor',
  'paint-brush',
  'paw',
  'pepper-hot',
  'pied-piper-hat',
  'pizza-slice',
  'portrait',
  'puzzle-piece',
  'rainbow',
  'redhat',
  'robot',
  'rocket',
  'running',
  'seedling',
  'skating',
  'skiing',
  'smile',
  'snowboarding',
  'snowflake',
  'snowman',
  'swimmer',
  'umbrella',
  'user-astronaut',
  'user-graduate',
  'user-ninja',
  'user-secret',
  'walking',
  'yin-yang',
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
