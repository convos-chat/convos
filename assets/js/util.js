const goldenRatio = 0.618033988749;

export function debounce(cb, delay) {
  let timeout;

  return function(...args) {
    const self = this; // eslint-disable-line no-invalid-this
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(function() { cb.apply(self, args) }, delay);
  };
}

export function camelize(str) {
  return str.replace(/_(\w)/g, (a, b) => b.toUpperCase());
}

export function closestEl(el, needle) {
  while (el) {
    if (needle.tagName ? el == needle : el.matches ? el.matches(needle) : false) return el;
    el = el.parentNode;
  }
  return null;
}

export function ensureChildNode(parent, className, cb) {
  let childNode = parent && parent.querySelector(className);
  if (childNode) return childNode;
  childNode = document.createElement('div');
  childNode.className = className;
  if (parent) parent.appendChild(childNode);
  if (cb) cb(childNode);
  return childNode;
}

export function extractErrorMessage(params) {
  const errors = params.errors;
  return errors && errors[0] ? errors[0].message || 'Unknown error.' : '';
}

export function hidden(bool) {
  return bool ? 'hidden' : '';
}

export function q(parentEl, sel, cb) {
  const els = parentEl.querySelectorAll(sel);
  if (!cb) return [].slice.call(els, 0);
  const res = [];
  for (let i = 0; i < els.length; i++) res.push(cb(els[i], i));
  return res;
}

export function regexpEscape(str) {
  return str.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&');
}

export function removeChildNodes(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
}

export function sortByName(a, b) {
  return a.name.localeCompare(b.name);
}

export function tagNameIs(el, tagName) {
  return el && el.tagName && el.tagName.toLowerCase() === tagName;
}

export function timer(t, success = true) {
  return new Promise((resolve, reject) => {
    setTimeout(success ? resolve : reject, t);
  });
}

export function str2color(str, nColors = 100) {
  if (str.length == 0) return '#000';

  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
    hash = hash & hash;
  }

  hash = Math.abs((hash % nColors) / nColors);
  return '#' + hsvToRgb(((hash + goldenRatio) % 1), 0.4, 0.7).map(c => c.toString(16)).join('');
}

export function hsvToRgb(hue = 0, saturation = 0.5, value = 0.95) {
  var hi = Math.floor(hue * 6);
  var f = hue * 6 - hi;
  var p = value * (1 - saturation);
  var q = value * (1 - f * saturation);
  var t = value * (1 - (1 - f) * saturation);
  var red = 255;
  var green = 255;
  var blue = 255;

  switch (hi) {
    case 0: red = value; green = t;     blue = p; break;
    case 1: red = q;     green = value; blue = p; break;
    case 2: red = p;     green = value; blue = t; break;
    case 3: red = p;     green = q;     blue = value; break;
    case 4: red = t;     green = p;     blue = value; break;
    case 5: red = value; green = p;     blue = q; break;
  }

  return [Math.floor(red * 255), Math.floor(green * 255), Math.floor(blue * 255)];
}

// https://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript
export function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    let r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}
