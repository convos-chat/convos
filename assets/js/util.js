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

export function epoch() {
  return new Date().getTime();
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

// https://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript
export function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    let r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}
