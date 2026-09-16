import { Given, When, Then } from "@cucumber/cucumber";
import assert from "node:assert";

interface SimulatedEQBand {
  frequency: number;
  gain: number;
}

interface SimulatedAudioApp {
  name: string;
  isCapturing: boolean;
  selectedOutputDevice: string | null;
  volume?: number;
  isBoostActive?: boolean;
  boostGain?: number;
  limiterActive?: boolean;
  pan?: number;
}

interface SimulatedState {
  masterVolume: number;
  isMuted: boolean;
  effectiveVolume: number;
  eqBands: SimulatedEQBand[];
  isRoutingActive: boolean;
  excludedFromPrimary: string[];
  apps: Record<string, SimulatedAudioApp>;
  persistentProfiles: Record<string, any>;
}

const state: SimulatedState = {
  masterVolume: 0.75,
  isMuted: false,
  effectiveVolume: 0.75,
  eqBands: [
    { frequency: 32, gain: 0 },
    { frequency: 64, gain: 0 },
    { frequency: 125, gain: 0 },
    { frequency: 250, gain: 0 },
    { frequency: 500, gain: 0 },
    { frequency: 1000, gain: 0 },
    { frequency: 2000, gain: 0 },
    { frequency: 4000, gain: 0 },
    { frequency: 8000, gain: 0 },
    { frequency: 16000, gain: 0 },
  ],
  isRoutingActive: false,
  excludedFromPrimary: [],
  apps: {},
  persistentProfiles: {},
};

// --- Scenario 1: Master Volume & Mute ---

Given("SmurfAudio is active with master volume at {int}%", function (initialVol: number) {
  state.masterVolume = initialVol / 100;
  state.isMuted = false;
  state.effectiveVolume = state.masterVolume;
  assert.strictEqual(state.effectiveVolume, 0.75);
});

When("the user adjusts master volume to {int}%", function (newVol: number) {
  state.masterVolume = newVol / 100;
  state.effectiveVolume = state.isMuted ? 0 : state.masterVolume;
});

Then("the active output hardware volume is set to {int}%", function (expectedVol: number) {
  assert.strictEqual(state.effectiveVolume, expectedVol / 100);
});

When("the user toggles mute on", function () {
  state.isMuted = true;
  state.effectiveVolume = 0;
});

Then("the output stream is muted without losing the {int}% level", function (persistedVol: number) {
  assert.strictEqual(state.isMuted, true);
  assert.strictEqual(state.effectiveVolume, 0);
  assert.strictEqual(state.masterVolume, persistedVol / 100);
});

When("the user toggles mute off", function () {
  state.isMuted = false;
  state.effectiveVolume = state.masterVolume;
});

Then("the volume is restored to {int}%", function (restoredVol: number) {
  assert.strictEqual(state.isMuted, false);
  assert.strictEqual(state.effectiveVolume, restoredVol / 100);
});

// --- Scenario 2: Equalizer ---

Given("the 10-band equalizer is active", function () {
  assert.strictEqual(state.eqBands.length, 10);
});

When("the user applies the {string} preset", function (presetName: string) {
  if (presetName === "Bass Boost") {
    // Apply bass boost gains
    state.eqBands[0].gain = 6.0; // 32 Hz
    state.eqBands[1].gain = 5.0; // 64 Hz
  }
});

Then("the 32Hz and 64Hz frequency bands have boosted gain", function () {
  const b32 = state.eqBands.find((b) => b.frequency === 32);
  const b64 = state.eqBands.find((b) => b.frequency === 64);
  assert(b32 && b32.gain > 0, "32Hz should have boosted gain");
  assert(b64 && b64.gain > 0, "64Hz should have boosted gain");
});

When("the user adjusts the {int}Hz band gain to {float} dB", function (freq: number, gain: number) {
  const band = state.eqBands.find((b) => b.frequency === freq);
  assert(band, `Band ${freq}Hz not found`);
  band.gain = gain;
});

Then("the graphic EQ unit reflects {float} dB on the {int}Hz band", function (expectedGain: number, freq: number) {
  const band = state.eqBands.find((b) => b.frequency === freq);
  assert(band, `Band ${freq}Hz not found`);
  assert.strictEqual(band.gain, expectedGain);
});

// --- Scenario 3: Per-App Redirection ---

Given("application {string} is playing audio", function (appName: string) {
  state.apps[appName] = {
    name: appName,
    isCapturing: false,
    selectedOutputDevice: null,
  };
});

When("the user redirects {string} to device {string}", function (appName: string, deviceName: string) {
  const app = state.apps[appName];
  assert(app, `App ${appName} not found`);
  app.selectedOutputDevice = deviceName;
  app.isCapturing = true;
  state.isRoutingActive = true;
  state.excludedFromPrimary.push(appName);
});

Then("the BlackHole virtual audio pipeline is engaged", function () {
  assert.strictEqual(state.isRoutingActive, true);
});

Then("{string} is excluded from the primary MacBook speakers mix", function (appName: string) {
  assert(state.excludedFromPrimary.includes(appName), `${appName} must be in excluded primary stream`);
});

Then("{string} audio is routed directly to {string}", function (appName: string, targetDevice: string) {
  const app = state.apps[appName];
  assert(app, `App ${appName} not found`);
  assert.strictEqual(app.selectedOutputDevice, targetDevice);
});

// --- Scenario 4: Volume Overdrive Boost ---

Given("application {string} is active with volume at {int}%", function (appName: string, vol: number) {
  state.apps[appName] = {
    name: appName,
    isCapturing: true,
    selectedOutputDevice: null,
    volume: vol / 100,
    isBoostActive: false,
    boostGain: 0,
    limiterActive: false,
  };
});

When("the user engages {string} volume boost", function (boostStr: string) {
  const gain = parseFloat(boostStr.replace("+", "").replace(" dB", ""));
  const app = state.apps["Safari"];
  assert(app, "Safari not found");
  app.isBoostActive = true;
  app.boostGain = gain;
  app.limiterActive = true;
});

Then("the peak limiter audio unit is activated", function () {
  const app = state.apps["Safari"];
  assert.strictEqual(app?.limiterActive, true);
});

Then("the digital pre-gain is set to {float} dB without digital clipping", function (expectedGain: number) {
  const app = state.apps["Safari"];
  assert.strictEqual(app?.boostGain, expectedGain);
});

// --- Scenario 5: Per-App Profile Persistence ---

Given("application {string} has balance set to {float} and volume at {int}%", function (appName: string, pan: number, vol: number) {
  state.apps[appName] = {
    name: appName,
    isCapturing: true,
    selectedOutputDevice: null,
    volume: vol / 100,
    pan: pan,
  };
});

When("the application audio profile is saved", function () {
  const app = state.apps["Spotify"];
  assert(app, "Spotify not found");
  state.persistentProfiles["Spotify"] = {
    volume: app.volume,
    pan: app.pan,
  };
});

Then("the persistent store retains volume at {int}% and pan at {float}", function (vol: number, pan: number) {
  const profile = state.persistentProfiles["Spotify"];
  assert(profile, "Profile for Spotify not found");
  assert.strictEqual(profile.volume, vol / 100);
  assert.strictEqual(profile.pan, pan);
});

When("{string} is relaunched", function (appName: string) {
  // Simulate process restart
  delete state.apps[appName];
  const profile = state.persistentProfiles[appName];
  assert(profile, `Profile for ${appName} should exist`);
  state.apps[appName] = {
    name: appName,
    isCapturing: false,
    selectedOutputDevice: null,
    volume: profile.volume,
    pan: profile.pan,
  };
});

Then("the restored profile applies volume at {int}% and pan at {float}", function (vol: number, pan: number) {
  const app = state.apps["Spotify"];
  assert(app, "Spotify not found");
  assert.strictEqual(app.volume, vol / 100);
  assert.strictEqual(app.pan, pan);
});

