Feature: SmurfAudio Audio Routing and Mixer Controls
  As a macOS user
  I want to control system volume, equalize audio, and route per-app streams
  So that I have precise granular control over my Mac audio hardware

  Scenario: Master volume adjustments and mute restoration
    Given SmurfAudio is active with master volume at 75%
    When the user adjusts master volume to 40%
    Then the active output hardware volume is set to 40%
    When the user toggles mute on
    Then the output stream is muted without losing the 40% level
    When the user toggles mute off
    Then the volume is restored to 40%

  Scenario: Equalizer preset selection and band adjustment
    Given the 10-band equalizer is active
    When the user applies the "Bass Boost" preset
    Then the 32Hz and 64Hz frequency bands have boosted gain
    When the user adjusts the 1000Hz band gain to 4.5 dB
    Then the graphic EQ unit reflects 4.5 dB on the 1000Hz band

  Scenario: Per-app audio redirection through BlackHole pipeline
    Given application "Music" is playing audio
    When the user redirects "Music" to device "USB Headset"
    Then the BlackHole virtual audio pipeline is engaged
    And "Music" is excluded from the primary MacBook speakers mix
    And "Music" audio is routed directly to "USB Headset"

  Scenario: Volume overdrive boost with peak limiter protection
    Given application "Safari" is active with volume at 100%
    When the user engages "+6 dB" volume boost
    Then the peak limiter audio unit is activated
    And the digital pre-gain is set to 6.0 dB without digital clipping

  Scenario: Per-app audio profile persistence and stereo balance
    Given application "Spotify" has balance set to -0.5 and volume at 60%
    When the application audio profile is saved
    Then the persistent store retains volume at 60% and pan at -0.5
    When "Spotify" is relaunched
    Then the restored profile applies volume at 60% and pan at -0.5

