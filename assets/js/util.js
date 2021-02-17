/**
 * util holds a collection of utility functions.
 *
 * @module util
 * @exports calculateModes
 * @exports camelize
 * @exports clone
 * @exports closestEl
 * @exports copyToClipboard
 * @exports debounce
 * @exports ensureChildNode
 * @exports extractErrorMessage
 * @exports findVisibleElements
 * @exports hsvToRgb
 * @exports humanReadableNumber
 * @exports isType
 * @exports loadScript
 * @exports modeClassNames
 * @exports q
 * @exports regexpEscape
 * @exports removeChildNodes
 * @exports sameOrigin
 * @exports settings
 * @exports showFullscreen
 * @exports str2color
 * @exports tagNameIs
 * @exports timer
 * @exports uuidv4
 */

const goldenRatio = 0.618033988749;
const k = 1000;
const M = k * 1000;
const G = M * 1000;

/**
 * Takes a string, and turns it into an object with true/false values.
 *
 * @param {Object} modeMap An object with single character keys and descriptive values.
 * @param {String} modeStr Example: "vo", "+o" or "-vxyz"
 * @returns {Object}
 */
export function calculateModes(modeMap, modeStr) {
  const [all, addRemove, modeList] = (modeStr || '').match(/^(\+|-)?(.*)/) || ['', '+', ''];
  const modes = {};
  modeList.split('').forEach(char => (modes[modeMap[char] || char] = addRemove != '-'));
  return modes;
}

/**
 * Used to take snake case and turn it into camel case.
 *
 * @param {String} str Example: foo_bar_baz
 * @returns {String} Example: fooBarBaz
 */
export function camelize(str) {
  return str.replace(/_(\w)/g, (a, b) => b.toUpperCase());
}

/**
 * Takes a JSON object or undefined and makes a deep copy.
 *
 * @param {Object} any
 * @returns {Object}
 */
export function clone(any) {
  if (any === undefined) return undefined;
  return JSON.parse(JSON.stringify(any));
}

/**
 * closestEl() is very much the same as HTMLElement.closest(), but can also
 * match another HTMLElement.
 *
 * @param {HTMLElement} el The node to search from.
 * @param {HTMLElement} needle Another DOM node.
 * @param {String} needle A CSS selector.
 * @returns {HTMLElement} The node that matches the needle
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
  const db = function(...args) {
    const self = this; // eslint-disable-line no-invalid-this
    if (db.debounceTid) clearTimeout(db.debounceTid);
    db.debounceTid = setTimeout(function() { cb.apply(self, args); db.debounceTid = 0 }, delay);
  };

  db.debounceTid = 0;
  return db;
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

/**
 * This function will find visible elements.
 *
 * @param {HTMLElement} containerEl A node containing zero or more child nodes.
 * @param {HTMLElement} scrollEl A scrollable element
 * @returns {Array} An array of visible child nodes.
 */
export function findVisibleElements(containerEl, scrollEl = document) {
  const els = [...containerEl.childNodes]; // Convert to array
  const haystack = [];

  // Filter out comments, text nodes, ...
  let i = 0;
  while (i < els.length) {
    if (els[i].nodeType == Node.ELEMENT_NODE) {
      haystack.push([i, els[i]]);
      i++;
    }
    else {
      els.splice(i, 1);
    }
  }

  // No child nodes
  if (!els.length) return [];

  // Find fist visible element
  const scrollTop = scrollEl.scrollTop;
  while (haystack.length > 1) {
    const index = Math.floor(haystack.length / 2);
    if (haystack[index][1].offsetTop <= scrollTop) {
      haystack.splice(0, index);
    }
    else {
      haystack.splice(index);
    }
  }

  if (!haystack.length) haystack.push([0, els[0]]);

  // Figure out the first and last visible element
  const offsetHeight = scrollEl.offsetHeight;
  const first = haystack[0][0];
  let last = first;
  while (last < els.length) {
    if (els[last].offsetTop > scrollTop + offsetHeight) break;
    last++;
  }

  return els.slice(first, last).filter(el => !el.getAttribute('aria-hidden'));
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

/*
 * humanReadableNumber() will take a number and return a number in kilo, mega
 * or giga.
 *
 * @param {Number} n Number of bytes
 * @returns {String} Example: 2.4k, 3.4M or 8G
 */
export function humanReadableNumber(n, suffix) {
  const h = n < k ? [n, '']
          : n < M ? [n / k, 'k']
          : n < G ? [n / M, 'M']
          :         [n / G, 'G'];

  const v = String(Math.round(h[0] * 10) / 10);
  return (v.match(/\./) ? v : v + '.0') + h[1] + (suffix ? suffix : '');
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
 * @return {Promise} Resolved when script is loaded.
 */
export function loadScript(src) {
  const d = document;
  const id = src.replace(/\W/g, '_');
  if (d.getElementById(id)) return;

  const el = d.createElement('script');
  [el.id, el.src] = [id, src];
  d.getElementsByTagName('head')[0].appendChild(el);

  return new Promise((resolve, reject) => {
    el.addEventListener('error', reject);
    el.addEventListener('load', resolve);
  });
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
 * q() is a simpler and shorter version of querySelectorAll(). This function
 * can also be used to add event listeners.
 *
 * @example
 * const divs = q(document, 'div'); // Array and not HTMLCollection
 * const hrefs = q(document, 'a', (el) => el.href);
 * const hrefs = q(document, 'a', ['click', (e) => { ... }]);
 *
 * @param {HTMLElement} parentEl Where you want to start searching.
 * @param {String} sel A CSS selector passed on to querySelectorAll().
 * @param {Function} cb Optional callback to call on each found DOM node.
 */
export function q(parentEl, sel, cb) {
  const els = sel == ':children' ? parentEl.children : parentEl.querySelectorAll(sel);
  if (!cb) return [].slice.call(els, 0);
  if (Array.isArray(cb)) return [].forEach.call(els, el => el.addEventListener(cb[0], cb[1]));
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
 * // Will replace what is currently the class with "for-cms"
 * replaceClassName('body', /(for-)app/, 'cms');
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
 * settings() is used to get or set global settings.
 *
 * @param {String} key The setting name.
 * @param {String} value A setting value. (omit to "get" the value)
 * @return {String} The settings value on "get"
 */
export function settings(key, value) {
  const getEl = (key) => document.querySelector('meta[name="convos:' + key + '"]')
      || document.querySelector('meta[name="' + key + '"]');

  // Get
  if (arguments.length == 1) {
    if (key == 'app_mode') return document.body.classList.contains('for-app');
    if (key == 'notify_enabled') return document.body.classList.contains('notify-enabled');
    if (key == 'organization_name') key = 'contactorganization';
    if (key == 'organization_url') key = 'contactnetworkaddress';
    const el = getEl(key);
    if (!el) throw 'Cannot get settings for "' + key + '".';
    const bool = {no: false, yes: true};
    return key == 'contact' ? atob(el.content || '') : bool.hasOwnProperty(el.content) ? bool[el.content] : el.content;
  }

  // Set
  if (key == 'app_mode') return replaceClassName('body', /(for-)(app|cms)/, value ? 'app' : 'cms');
  if (key == 'notify_enabled') return replaceClassName('body', /(notify-)(disabled)/, value ? 'enabled' : 'disabled');
  if (key == 'organization_name') key = 'contactorganization';
  if (key == 'organization_url') key = 'contactnetworkaddress';
  if (key == 'contact') value = btoa(value);
  if (typeof value == 'boolean') value = value ? 'yes' : 'no';
  getEl(key).content = value;
}

/**
 * showFullscreen() is used put some content inside a fullscreen wrapper.
 *
 * @param {Event} e Ex: A click event
 * @param {HTMLElement} contentEl A node to place inside the wrapper
 * @return {HTMLElement} The fullscreen wrapper
 */
export function showFullscreen(e, contentEl) {
  if (e && e.preventDefault) e.preventDefault();

  const mediaWrapper = ensureChildNode(document.body, 'fullscreen', (el) => {
    el.addEventListener('click', (e) => e.target == el && el.hide());
    el.hide = () => mediaWrapper.classList.add('hidden');
  });

  removeChildNodes(mediaWrapper);
  if (!contentEl) return mediaWrapper.hide();

  mediaWrapper.classList.remove('hidden');
  mediaWrapper.appendChild(contentEl.cloneNode(true));
  return mediaWrapper;
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
  if (isType(tagName, 'array')) return tagName.find(name => tagNameIs(el, name)) || false;
  return el && el.tagName && el.tagName.toLowerCase() === tagName || false;
}

/**
 * Combines setTimeout() and Promise.
 *
 * @param {Number} ms Number of milliseconds before resolving the promise
 * @param {Any} success Will reject the promise if it is a string
 * @returns {Promise} A promise to be resolved/rejected in the future
 */
export function timer(ms, res = true) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      typeof res == 'function' ? resolve(res()) : typeof res == 'string' ? reject(res) : resolve(res);
    }, ms);
  });
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
