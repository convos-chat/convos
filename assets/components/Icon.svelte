<script context="module">
const familyToClassName = {brand: 'fab', regular: 'far', solid: 'fas'};

const contributorIcons = {
  batman: 'https://www.gravatar.com/avatar/ab1839667863f31e359d98364cfdef61',
  marcusr: 'https://www.gravatar.com/avatar/6c056546d802b1a9ac186ab63f9fb632',
};

const pickIcons = [
  'fas fa-anchor',
  'fas fa-atom',
  'fas fa-award',
  'fas fa-balance-scale',
  'fas fa-baseball-ball',
  'fas fa-basketball-ball',
  'fas fa-bicycle',
  'fas fa-bolt',
  'fas fa-book-reader',
  'fas fa-candy-cane',
  'fas fa-carrot',
  'fas fa-cat',
  'fas fa-chess-knight',
  'fas fa-child',
  'fas fa-coffee',
  'fas fa-cookie-bite',
  'fas fa-crow',
  'fas fa-dice',
  'fas fa-dog',
  'fas fa-dove',
  'fas fa-feather',
  'fas fa-fish',
  'fas fa-gem',
  'fas fa-ghost',
  'fas fa-hard-hat',
  'fas fa-hat-cowboy',
  'fas fa-hat-wizard',
  'fas fa-hiking',
  'fas fa-horse-head',
  'fas fa-horse',
  'fas fa-id-badge',
  'fas fa-igloo',
  'fas fa-mask',
  'fas fa-meteor',
  'fas fa-paint-brush',
  'fas fa-paw',
  'fas fa-pepper-hot',
  'fas fa-pizza-slice',
  'fas fa-portrait',
  'fas fa-puzzle-piece',
  'fas fa-rainbow',
  'fas fa-robot',
  'fas fa-rocket',
  'fas fa-running',
  'fas fa-seedling',
  'fas fa-skating',
  'fas fa-skiing',
  'fas fa-smile',
  'fas fa-snowboarding',
  'fas fa-snowflake',
  'fas fa-snowman',
  'fas fa-swimmer',
  'fas fa-umbrella',
  'fas fa-user-astronaut',
  'fas fa-user-graduate',
  'fas fa-user-ninja',
  'fas fa-user-secret',
  'fas fa-walking',
  'fas fa-yin-yang',
];
</script>

<script>
let className = '';

export {className as class};
export let animation = '';
export let color = '';
export let family = '';
export let name;

function calculateClassName(name, family) {
  const cn = [];
  const pick = name.match(/^pick:(.+)$/);

  if (pick) {
    if (pick[1] == 'Convos') return 'fas fa-info-circle'; // Uppercase "C" is not a typo
    if (contributorIcons[pick[1]]) return 'fas fa-contributor for-' + pick[1].toLowerCase();
    cn.push(pickIcon(pick[1]));
  }
  else {
    cn.push(familyToClassName[family] || 'fas');
    cn.push('fa-' + name);
  }

  if (animation) cn.push(animation.split(' ').map(a => 'fa-' + a));
  if (className) cn.push(className.split(' '));

  return cn.join(' ');
}

function calculateStyle(name, color) {
  const rules = [];
  let colorRuleName = 'color:';

  const pick = name.match(/^pick:(.+)$/);
  if (pick && contributorIcons[pick[1]]) {
    colorRuleName = 'background-color:';
    rules.push('background-image:url("' + contributorIcons[pick[1]] + '")');
  }

  if (color) {
    rules.push(colorRuleName + color);
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
  style="{calculateStyle(name, color)}"
  hidden="{!name}"
  on:click/>
