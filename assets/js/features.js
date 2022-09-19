const features = {
  add(name) {
    document.body.classList.remove('no-' + name);
    document.body.classList.add('has-' + name);
  },
  has(name) {
    return document.body.classList.contains('has-' + name);
  },
  remove(name) {
    document.body.classList.add('no-' + name);
    document.body.classList.remove('has-' + name);
  },
};

detectEvent('mousemove', 'mouse');
detectEvent('touchstart', 'touch');
features.add('js');

function detectEvent(eventName, featureName) {
  const cb = (e) => {
    if (eventName !== 'mousemove') features.add(featureName);
    if (eventName === 'mousemove' && !features.has('touch')) features.add(featureName);
    document.removeEventListener(eventName, cb);
  };

  document.addEventListener(eventName, cb);
}

export default features;
