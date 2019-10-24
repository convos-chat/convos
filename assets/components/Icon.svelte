<script>
const familyToClassName = {regular: 'far', solid: 'fas'};

const contributorIcons = {
  batman: 'https://www.gravatar.com/avatar/806800a3aeddbad6af673dade958933b',
  marcusr: 'https://www.gravatar.com/avatar/6c056546d802b1a9ac186ab63f9fb632',
};

const pickIcons = [
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

export {className as class};
export let animation = '';
export let family = '';
export let name;
export let style = '';
export let title = '';

function calculateClassName(name, family) {
  const pick = name.match(/^pick:(.+)$/);
  if (pick && contributorIcons[pick[1]]) return 'fa fa-contributor';

  const cn = [className, familyToClassName[family] || 'fa'];
  cn.push('fa-' + (name && name.indexOf('pick:') == 0 ? pickIcon(name) : name));
  if (animation) cn.push(animation.split(' ').map(a => 'fa-' + a));
  if (className) cn.push(className.split(' '));

  return cn.join(' ');
}

function calculateStyle(name, family, style) {
  const rules = [];
  if (style) rules.push(style);

  const pick = name.match(/^pick:(.+)$/);
  if (pick && contributorIcons[pick[1]]) {
    rules.push('background-image:url("' + contributorIcons[pick[1]] + '")');
  }

  return rules.join(';');
}

function pickIcon(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
    hash = hash & hash;
  }

  hash = Math.abs(hash);
  return pickIcons[hash % pickIcons.length];
}
</script>

<i class="{calculateClassName(name, family)}"
  style="{calculateStyle(name, family, style)}"
  title="{title}"
  hidden="{!name}"
  on:click/>
