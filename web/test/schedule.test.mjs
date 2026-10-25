import assert from 'node:assert/strict';
import test from 'node:test';
import { LEAD, MAX_AHEAD, frameTimestampUs, planSchedule } from '../src/schedule.js';

test('first chunk starts one lead-time ahead', () => {
  assert.deepEqual(planSchedule(10, 0), { start: 10 + LEAD, drop: false });
});

test('chunks queue back to back while the buffer is healthy', () => {
  assert.deepEqual(planSchedule(10, 10.4), { start: 10.4, drop: false });
});

test('an underrun rebuffers instead of playing late audio', () => {
  assert.deepEqual(planSchedule(10, 9.9), { start: 10 + LEAD, drop: false });
  assert.deepEqual(planSchedule(10, 10.01), { start: 10 + LEAD, drop: false });
});

test('a burst that puts us too far behind real time is dropped', () => {
  assert.equal(planSchedule(10, 10 + MAX_AHEAD + 0.1).drop, true);
  assert.equal(planSchedule(10, 10 + MAX_AHEAD - 0.1).drop, false);
});

test('AAC frame timestamps advance by 1024 samples', () => {
  assert.equal(frameTimestampUs(0, 48000), 0);
  assert.equal(frameTimestampUs(1, 48000), 21333);
  assert.equal(frameTimestampUs(48, 48000), 1024000);
});
