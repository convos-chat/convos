const levels = ['trace', 'debug', 'info', 'warn', 'error'];
const loggers = {};
const nameToLevel = {};
const noop = () => {};

// Need a root logger
loggers.root = new Logger({name: 'root'});

function defaultLogLevel(log, name) {
  if (nameToLevel.root === undefined) {
    let levels = (location.href.match(/_debug=([a-z,:]+)/) || []).pop();
    if (levels) {
      levels.split(',').forEach(kv => {
        const [name, value] = kv.split(':');
        nameToLevel[name] = value || 'debug';
      });
      localStorage.setItem('logger:nameToLevel', JSON.stringify(nameToLevel));
    }
    else if ((levels = localStorage.getItem('logger:nameToLevel'))) {
      levels = JSON.parse(levels);
      Object.keys(levels).forEach((name, value) => (nameToLevel[name] = value || 'debug'));
    }
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

  this.setLevel(defaultLogLevel(name == 'root' ? this : loggers.root, name));
}

export function getLogger(name = 'root') {
  return loggers[name] || (loggers[name] = new Logger({name}));
}
