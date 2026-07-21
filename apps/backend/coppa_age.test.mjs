import test from 'node:test';
import assert from 'node:assert/strict';
import { isUnder13 } from './server.mjs';

test('backend permits a user who is 13', () => assert.equal(isUnder13('2013-07-21'), false));
test('backend rejects a user under 13', () => assert.equal(isUnder13('2013-07-22'), true));
test('backend rejects malformed age input', () => assert.equal(isUnder13('21/07/2013'), null));
