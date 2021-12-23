const levels = ['trace', 'debug', 'info', 'warn', 'error'];
const loggers = {};
const nameToLevel = {};
const noop = () => {};

// Need a root logger
loggers.root = new Logger({name: 'root'});

function defaultLogLevel(name) {
  if (nameToLevel.root === undefined) {
    Object.entries(JSON.parse(localStorage.getItem('logger:nameToLevel') || '{}')).forEach(([k, v]) => {
      nameToLevel[k] = v || 'debug';
    });

    ((location.href.match(/_debug=([a-z,:]+)/) || []).pop() || '').split(',').forEach(kv => {
      const [k, v] = kv.split(':');
      nameToLevel[k] = v || 'debug';
    });

    localStorage.setItem('logger:nameToLevel', JSON.stringify(nameToLevel));
  }

  return nameToLevel[name] || nameToLevel.root || 'info';
}

function Logger({name}) {
  this.name = name;

  this.isLevel = (level) => {
    const numLevel = levels.indexOf(level) || level || level.length;
    return this.numLevel >= numLevel;
  };

  this.setLevel = (level) => {
    let numLevel = levels.indexOf(level);
    if (numLevel == -1) numLevel = 2; // default to "info"
    this.numLevel = numLevel;

    levels.forEach((name, i) => {
      const methodName = name == 'trace' || name == 'debug' ? 'log' : name;
      const method = !console || i < numLevel ? noop : console[methodName] || console.log || noop;
      this[name] = method.bind(this, '[' + this.name + ']');
    });

    return this;
  };

  this.setLevel(defaultLogLevel(name));
}

export function getLogger(name = 'root') {
  return loggers[name] || (loggers[name] = new Logger({name}));
}
