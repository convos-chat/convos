import Reactive from '../assets/js/Reactive';

test('prop', () => {
  const r = reactive('Superman');
  expect(r.name).toBe('Superman');

  ['age', 'name'].forEach(prop => {
    try {
      r[prop] = 'foo';
      expect('').toBeGreaterThan(4);
    } catch(err) {
      expect(err.toString().length).toBeGreaterThan(4);
    }
  });
});

test('prop persist', () => {
  const r = reactive('Superman');

  r.prop('persist', 'num', undefined);
  expect(localStorage.getItem('convos:num')).toBe('undefined');

  r.update({num: 42});
  expect(r.num).toBe(42);
  expect(localStorage.getItem('convos:num')).toBe('42');

  r.update({num: '42'});
  expect(localStorage.getItem('convos:num')).toBe('"42"');
});

test('on', () => {
  const r = reactive('On');

  const got = [];
  const unsubscribe = r.on('foo', (...params) => got.push(params));

  r.emit('foo', 1, 2, 3);
  r.emit('foo', 4, 5);

  unsubscribe();
  r.emit('foo', 6, 7);

  expect(got).toEqual([[1, 2, 3], [4, 5]]);
});

test('on promise', () => {
  const r = reactive('On');

  setTimeout(() => r.emit('foo', 1, 2, 3), 10);
  const unsubscribe = r.on('foo', (a) => a);

  return r.on('foo').then((...params) => {
    // Make sure we still have one subscriber
    expect(r._on.foo.length).toBe(1);

    // then() will only receive the first argument
    expect(params).toEqual([1]);

    unsubscribe();
    expect(r._on.foo.length).toBe(0);
  });
});

test('update() tracking props', () => {
  const r = reactive('Superman');

  r.update({age: 30});
  expect(r._updatedProps).toEqual({});

  r.update({age: '30'});
  expect(r._updatedProps).toEqual({age: true});

  r._updatedProps = {};
  r.update({name: 'Superman', age: 31, whatever: 'whatever'});
  r.update({name: 'Superman', address: 'Metropolis'});
  expect(r._updatedProps).toEqual({address: true, age: true, name: false});
});

test('update() emit', (done) => {
  const r = reactive('Superwoman');

  r.on('update', (obj, updated) => {
    expect(obj).toEqual(r);
    expect(updated).toEqual({address: true, age: true, name: false});
    done();
  });

  r.update({name: 'Superwoman', age: 30});
  r.update({name: 'Superman', age: 31, whatever: 'whatever'});
  r.update({name: 'Superman', address: 'Metropolis'});
});

test('subscribe()', (done) => {
  const r = reactive('Superduper');

  let n = 0;
  // The callback will be called once when subscribing
  r.subscribe((obj) => {

    // Read-only attributes will cause 'update' to be emitted again
    if (++n == 2) obj.update({name: true});

    // Will be ignored
    r.update({age: 31, unknown: 'foo'});
  });

  // Will cause subscribe() callback to be called once
  r.update({name: 'Superwoman', age: 30});
  r.update({name: 'Superman', age: 31, whatever: 'whatever'});
  r.update({name: 'Superman', address: 'Metropolis'});
  r.update({force: 1});

  setTimeout(() => {
    expect(n).toBe(3);
    done();
  }, 100);
});

function reactive(name) {
  const r = new Reactive();
  r.prop('ro', 'name', name);
  r.prop('rw', 'age', 30);
  r.prop('rw', 'address', '');
  return r;
}
