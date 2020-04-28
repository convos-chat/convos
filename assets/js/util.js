/**
 * util holds a collection of utility functions.
 *
 * @module util
 * @exports camelize
 * @exports clone
 * @exports closestEl
 * @exports copyToClipboard
 * @exports debounce
 * @exports ensureChildNode
 * @exports extractErrorMessage
 * @exports hsvToRgb
 * @exports isType
 * @exports loadScript
 * @exports modeClassNames
 * @exports q
 * @exports regexpEscape
 * @exports removeChildNodes
 * @exports sameOrigin
 * @exports showEl
 * @exports str2color
 * @exports tagNameIs
 * @exports uuidv4
 */
const goldenRatio = 0.618033988749;

/**
 * Used to take snake case and turn it into camel case.
 *
 * @param {String} str Example: foo_bar_baz
 * @returns {String} Example: fooBarBaz
 */
export function camelize(str) {
  return str.replace(/_(\w)/g, (a, b) => b.toUpperCase());
}

export function clone(any) {
  return JSON.parse(JSON.stringify(any));
}

/**
 * closestEl() is very much the same as HTMLElement.closest(), but can also
 * match another HTMLElement.
 *
 * @param {HTMLElement} el The node to search from.
 * @param {HTMLElement} needle Another DOM node.
 * @param {String} needle A CSS selector.
 * @returns {Boolean} True if the "needle" exists as self or parent node.
 */
export function closestEl(el, needle) {
  while (el) {
    if (needle.tagName ? el == needle : el.matches ? el.matches(needle) : false) return el;
    el = el.parentNode;
  }
  return null;
}

/**
 * copyToClipboard() can be used to copy text from an element to the clipboard.
 *
 * @param {HTMLElement} el A DOM node
 */
export function copyToClipboard(el) {
  const ta = document.createElement('textarea');
  ta.value = el.textContent || el.value;
  ta.style.opacity = 0;
  ta.style.position = 'absolute';
  document.body.appendChild(ta);

  try {
    ta.focus();
    ta.select();
    document.execCommand('copy');
  } catch(err) {
    ta.value = '';
    console.log('copyToClipboard() failed:', err);
  }

  document.body.removeChild(ta);
  return ta.value;
}

/**
 * debounce() can be used to delay the calling of a function. Each time the the
 * debounced function is called, it will delay number of milliseconds before
 * calling "cb".
 *
 * @param {Function} cb The function to call later.
 * @param {Integer} delay Number of milliseconds to wait before calling "cb".
 * @returns {Function} A debounced version of "cb".
 */
export function debounce(cb, delay) {
  let timeout;

  return function(...args) {
    const self = this; // eslint-disable-line no-invalid-this
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(function() { cb.apply(self, args) }, delay);
  };
}

/**
 * Will ensure that a child "div" node is present, with a given class name.
 *
 * @param {HTMLElement} parent The parent DOM node.
 * @param {String} className The class name to search for inside parent.
 * @param {Function} cb A callback to run if the child node was just created.
 * @returns {HTMLElement} The existing or newly created DOM node.
 */
export function ensureChildNode(parent, className, cb) {
  let childNode = parent && parent.querySelector('.' + className.split(' ').join('.'));
  if (childNode) return childNode;
  childNode = document.createElement('div');
  childNode.className = className;
  if (parent) parent.appendChild(childNode);
  if (cb) cb(childNode);
  return childNode;
}

/**
 * TODO: Probably move extractErrorMessage() to Operation.
 */
export function extractErrorMessage(params, from = 'message') {
  const errors = params.errors || params;
  return errors && errors[0] ? errors[0][from] || 'Unknown error.' : '';
}

export function focusMainInputElements(id) {
  if (id && 'ontouchstart' in window) return;

  if (id) {
    const el = document.getElementById(id);
    return el && el.focus();
  }

  const searchInput = document.getElementById('search_input');
  const targetEl = document.activeElement;
  if (targetEl != searchInput && !tagNameIs(targetEl, 'body')) return searchInput.focus();

  const selectors = ['#chat_input', '.main input[type="text"]', '.main a', '#search_input'];
  for (let i = 0; i < selectors.length; i++) {
    const el = document.querySelector(selectors[i]);
    if (el) return el.focus();
  }
}

/**
 * Used to generate a color.
 *
 * @param {Number} hue Amount of hue, between 0 and 1.
 * @param {Number} saturation Amount of saturation, between 0 and 1.
 * @param {Number} value How strong of a color, between 0 and 1.
 * @returns {Array} Tree integers (0-255) representing RGB.
 */
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

/**
 * isType is used to check if a value is a given type.
 *
 * - "array" will check if val is an array
 * - "object" will check if typeof is "object" and val is not null.
 * - "undef" will check for either typeof "undefined", or null.
 *
 * @param {Any} val Any value, including null
 * @param {String} type Either "object" or "undef"
 * @return {Boolean} True if val is an object
 */

export function isType(val, type) {
  return type == 'array'  ? Array.isArray(val)
       : type == 'object' ? typeof val == 'object' && val !== null
       : type == 'undef'  ? typeof val == 'undefined' || val === null
       : typeof val == type;
}

/**
 * loadScript() can be used to load a JavaScript. Calling it multiple times
 * with the same "src" will not reload the script.
 *
 * @param {String} src An URL to the script to load.
 */
export function loadScript(src) {
  const d = document;
  const id = src.replace(/\W/g, '_');
  if (d.getElementById(id)) return;

  const el = d.createElement('script');
  [el.id, el.src] = [id, src];
  d.getElementsByTagName('head')[0].appendChild(el);
}

/**
 * Used to take a participant mode string and turn it into CSS class names.
 *
 * @param {Object} modes Example: {operator: true}
 * @returns {String} Example: "has-mode-operator has-mode-voice"
 */
export function modeClassNames(modes) {
  return Object.keys(modes).filter(m => modes[m]).sort().map(m => { return 'has-mode-' + m }).join(' ');
}

/**
 * q() is a simpler and shorter version of querySelectorAll().
 *
 * @example
 * const divs = q(document, 'div'); // Array and not HTMLCollection
 * const hrefs = q(document, 'a', el => el.href);
 *
 * @param {HTMLElement} parentEl Where you want to start searching.
 * @param {String} sel A CSS selector passed on to querySelectorAll().
 * @param {Function} cb Optional callback to call on each found DOM node.
 */
export function q(parentEl, sel, cb) {
  const els = parentEl.querySelectorAll(sel);
  if (!cb) return [].slice.call(els, 0);
  const res = [];
  for (let i = 0; i < els.length; i++) res.push(cb(els[i], i));
  return res;
}

/**
 * regexpEscape() takes a string with unsafe characters and escapes them.
 *
 * @param {String} str Example: "(foo)"
 * @returns {String} Example: "\(foo\)"
 */
export function regexpEscape(str) {
  return str.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&');
}

/**
 * removeChildNodes() is used to remove all direct children of a DOM node.
 *
 * @param {HTMLElement} el A DOM parent node.
 */
export function removeChildNodes(el) {
  while (el.firstChild) el.removeChild(el.firstChild);
}

/**
 * replaceClassName() will replace a className by doing search and replace.
 *
 * @example
 * // Will replace what is currently the class with "is-logged-out"
 * replaceClassName('body', /is-logged-(\S+)/, 'out');
 *
 * @param {String} sel A CSS selector
 * @param {RegExp} re A RegExp to search for an existing class name
 * @param {String} replacement The value to replace
 */
export function replaceClassName(sel, re, replacement) {
  const tag = document.querySelector(sel);
  tag.className = tag.className.replace(re, (all, prefix) => prefix + replacement);
}

/**
 * sameOrigin() can be used to check if and URL is from the same domain as the
 * current document, or an optional URL.
 *
 * @param {String} url An URL to check
 * @param {Object} loc An URL to check against. Default to window.location.
 * @return {Boolean} True if `url` is from same origin as `loc`.
 */
export function sameOrigin(url, loc = location) {
  return url.indexOf('/') == 0 || url.indexOf('://' + loc.hostname) != -1;
}

/**
 * Used to show/hide an element or query the state of the element.
 *
 * @example
 * const isVisible = showEl(someEl, 'is-visible'); // Figure out if it is visible
 * showEl(someEl, 'toggle'); // Toggle between visible and hidden
 * showEl(someEl, true); // Force to visible
 * showEl(someEl, false); // Force to hidden
 *
 * @param {HTMLElement} el The element to show or hide.
 * @param {Boolean} show Instruct to show or hide the element.
 * @param {String} show Can be used to "toggle" the state or as a getter with "is-visible".
 * @returns {Boolean} If "show" is "is-visible".
 */
export function showEl(el, show) {
  if (show === 'is-visible') return !el.hasAttribute('hidden');
  if (show === 'toggle') show = el.hasAttribute('hidden');
  return show ? el.removeAttribute('hidden') : el.setAttribute('hidden', '');
}

/**
 * str2color() will hash the input string and use hsvToRgb() to convert the hash
 * value into a color.
 *
 * @param {String} str Any string
 * @param {nColors} nColors The number of colors to choose from. Default is 100.
 * @returns {String} Example: #138a8f
 */
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

/**
 * tagNameIs() will match the lower case version of the tag with the input
 * string.
 *
 * @param {HTMLElement} el A DOM node.
 * @param {String} tagName The tag name to match. Example: "div", "a".
 * @returns {Boolean} True if the tag name matches.
 */
export function tagNameIs(el, tagName) {
  return el && el.tagName && el.tagName.toLowerCase() === tagName || false;
}

/**
 * Used to generate a random UUID.
 * Taken from https://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript.
 *
 * @returns {String} The returned string has the format "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".
 */
export function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    let r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}
