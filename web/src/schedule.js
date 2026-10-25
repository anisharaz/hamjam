// Jitter-buffer policy for playing a live stream through Web Audio.
// Pure functions so they can be unit-tested without a browser.

export const LEAD = 0.35;      // seconds of audio buffered ahead when (re)starting
export const MIN_AHEAD = 0.03; // queue nearly empty: we are about to underrun
export const MAX_AHEAD = 1.5;  // too far behind real time: drop audio to stay live

/**
 * Decides when a freshly decoded chunk should start playing.
 * @param now  audio clock (AudioContext.currentTime)
 * @param next time the audio already queued will finish (0 before the first chunk)
 * @returns {{start:number, drop:boolean}} start time, or drop=true to skip the chunk
 */
export function planSchedule(now, next, { lead = LEAD, minAhead = MIN_AHEAD, maxAhead = MAX_AHEAD } = {}) {
  if (next < now + minAhead) return { start: now + lead, drop: false }; // first chunk or underrun: rebuffer
  if (next > now + maxAhead) return { start: next, drop: true };        // network burst: stay live
  return { start: next, drop: false };
}

/** Microsecond timestamp of the n-th AAC frame (1024 samples each). */
export const frameTimestampUs = (n, sampleRate) => Math.round((n * 1024 * 1e6) / sampleRate);
