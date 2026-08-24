# Legacy evidence intake

Status: EVIDENCE_ONLY  
Tasks: T103, T501  
Contracts: `asset-record-001`, `presentation-assets-001`, `visual-civic-seam-001`, `audio-haptics-001`  
Admission: LC-009 REJECT (wholesale visuals), LC-010 REJECT (wholesale audio), T102 EXCLUDE (non-SF)

## Frozen source

- Repository: `scrimshawlife-ctrl/Surveillance-Survivor`
- Commit: `3b20d88d6a6e1fe8f07f45f581359d371fa65d98`
- Specification pin: `39b04bb00ca5d3799513efed4e7970ec42975c96`

These files are ArtSources evidence. They are not runtime assets, are not referenced by `Package.swift` resources, and must not enter `App/` or the application bundle. Collision, targeting, and Camera fields must never be inferred from these sprites.

## Pulled binaries

San Francisco only. Nine other city packs and the rest of `Resources/RuntimeSprites` are classified in `asset-catalog-001.json` and were not copied.

### Visual (`visual/san_francisco/`)

| File | Decision | SHA-256 |
|---|---|---|
| `san_francisco_decal_cable_groove_01.png` | sfCandidate | `da1bb3d8b7075192792a38519ba35ad863d4ca3716b78afe31af844098aa247f` |
| `san_francisco_decal_damp_asphalt_01.png` | sfCandidate | `9fd13ebd6756eb9ed23a9b4981fbd146853f0fb61171e800bb66b1fd9e73c3db` |
| `san_francisco_landmark_bridge_distant_01.png` | rejected (Golden Gate / literal landmark shorthand) | `7380112ecfb098884474b2455e1e1849485ebad092d40ff2fe049f2c4f369b71` |
| `san_francisco_landmark_cable_track_01.png` | sfCandidate | `5c51e296bd7fe3e5c1dba1e8a10944d97779cf8bee45f072d1dfc39e698d6e92` |
| `san_francisco_landmark_comms_tower_01.png` | sfCandidate | `d00d33e734bb7561d6fe9cc833e254860cecb471af9099949f9a2d069d9ad787` |
| `san_francisco_landmark_victorian_midground_01.png` | sfCandidate | `feb92f76438e9b585c495e8844e6b44d394a5a0c5db816e092212df5d6d694f6` |
| `san_francisco_overlay_fog_band_01.png` | sfCandidate | `ab0869fea248ef97e066e91b771fa3107d7c39863094991705f70108e94e4888` |
| `san_francisco_overlay_improper_search_01.png` | sfCandidate | `1b6a992a32c187b541f9251f520cc6007bf8e36fd58ea0b1e62a9dcaec3ace0a` |
| `san_francisco_overlay_prediction_haze_01.png` | sfCandidate | `4b8f1095e0183d8f7416c65c1d68abad2eab7abe55eb5ea1da5b50428c3086d6` |
| `san_francisco_prop_av_shell_01.png` | sfCandidate | `b86bea5ee25759a4d5761789b2351543bce7539d3ded16de99ca4a37d985d33f` |
| `san_francisco_skyline_parallax_01.png` | sfCandidate | `222e76f122b5e0beff86cce5c66e0220a5afb6a2a620257b5b4150cc9d27663d` |
| `san_francisco_terrain_hill_stair_01.png` | sfCandidate | `c6d3eb8e19c76698cd2550acbfc177d61d9bfa667b379c1c1996e6081361970b` |
| `san_francisco_terrain_steep_arterial_01.png` | sfCandidate | `e447c45fd9fc14bb70996061fb67fac2cb983a1e792e639eec02ad21c6edc773` |

### Audio (`audio/san_francisco/`)

Delivery CAF hashes match legacy `docs/AUDIO_ASSET_MANIFEST.json` at the frozen commit.

| File | Decision | SHA-256 |
|---|---|---|
| `amb_san_francisco_city_identity_loop.caf` | rejected (LC-010) | `cbe1a14807589b910080f71a3c4b2685420f5ce9a7c85f829797244b365b1684` |
| `music_san_francisco_run_loop.caf` | rejected (LC-010) | `f85878eeb38fb88e872c2fe79331b324370c1ac4eb27b1acf06480ea6ad21808` |
| `music_san_francisco_boss_loop.caf` | rejected (LC-010) | `914470f84a0fdfa2fa6fcd845ea791df6cef9f6b719a99cab97608fe3225f336` |
| `sfx_san_francisco_hidden_sensor_fog.caf` | rejected (LC-010) | `d6e925e768222ebfcf5c0bd12cd3faef493f134105bb0a8f07003f842ece06e4` |

License recorded on the frozen audio manifest: ElevenLabs commercial license (owner account). That does not admit the clips against `audio-haptics-001` event IDs, priority, coalescence, or captions.

## Catalog

Machine-readable classification is `Sources/SurveillanceCore/Resources/contracts/asset-catalog-001.json`. Required HUD and audio IDs from `presentation-assets-001.json` exist there as `planned` / `projectOriginal` records with no files. Nothing in the catalog is `accepted`.
