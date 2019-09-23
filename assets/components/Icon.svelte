<script>
export let animation = '';
export let className = '';
export let family = '';
export let name;
export let style = '';
export let title = '';

const randomIcons = [
  'atom',
  'balance-scale',
  'baseball-ball',
  'book-reader',
  'cat',
  'chess-knight',
  'child',
  'dove',
  'fish',
  'hat-wizard',
  'hiking',
  'horse',
  'id-badge',
  'paw',
  'portrait',
  'running',
  'skating',
  'skiing',
  'smile',
  'snowboarding',
  'snowman',
  'swimmer',
  'user-astronaut',
  'user-graduate',
  'user-ninja',
  'user-secret',
  'walking',
];

const familyToClassName = {regular: 'far', solid: 'fas'};

let classNames = [];

$: {
  classNames = [familyToClassName[family] || 'fa'];
  classNames.push('fa-' + (name && name.indexOf('random:') == 0 ? randomIcon(name) : name));
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
