import Operation from '../../assets/store/Operation';

window.XMLHttpRequest = function() {
  this.response = '';
  this.getAllResponseHeaders = () => '';
  this.status = 200;
};

const api = {
  spec(id) {
    return Promise.resolve({id, method: 'get', url: 'https://loopback/foo.json'});
  },
};

describe('perform', () => {
  test('before', async () => {
    const op = new Operation({api, id: 'foo'});
    expect(op.req).toEqual({body: null, headers: {}});
    expect(op.res).toEqual({body: {}, headers: []});
    expect(op.status).toBe('pending');
  });

  test('error unknown', async () => {
    const op = new Operation({api, id: 'foo'});

    op._send = (xhr) => {
      xhr.status = 400;
      return Promise.resolve({});
    };

    expect(await op.perform({})).toEqual(op);
    expect(op.status).toBe('error');
    expect(op.req).toEqual({headers: {}, method: 'get', url: new URL('https://loopback/foo.json')});
    expect(op.res).toEqual({body: {}, headers: [], status: '400'});
    expect(op.err).toEqual([{message: 'Unknown error.'}]);
  });

  test('error body', async () => {
    const op = new Operation({api, id: 'foo'});

    op._send = (xhr) => {
      xhr.status = 500;
      xhr.response = '{"errors":[{"message":"Not cool"}]}';
      return Promise.resolve({});
    };

    expect(await op.perform({})).toEqual(op);
    expect(op.status).toBe('error');
    expect(op.req).toEqual({headers: {}, method: 'get', url: new URL('https://loopback/foo.json')});
    expect(op.res).toEqual({body: {errors: [{message: 'Not cool'}]}, headers: [], status: '500'});
    expect(op.err).toEqual([{message: 'Not cool'}]);
  });

  test('catch', async () => {
    const op = new Operation({api, id: 'foo'});

    op._send = () => Promise.reject('Yikes');
    expect(await op.perform({})).toEqual(op);
    expect(op.status).toBe('error');
    expect(op.req).toEqual({headers: {}, method: 'get', url: new URL('https://loopback/foo.json')});
    expect(op.res).toEqual({body: {errors: [{message: 'Yikes'}]}, headers: [], status: '599'});
    expect(op.err).toEqual([{message: 'Failed fetching operationId "foo": Yikes'}]);
  });
});
