# Cutscene Builder Production Standard

- **id:** `c18`
- **section:** production
- **class:** Technical Workflow
- **status:** Foundation
- **impact:** High

Author cinematics as reusable shot recipes compatible with layered pixel art and live game variables.

## Production notes

- A cutscene is a list of shots; a shot is a stack of layers; timing is expressed through keyframes and markers.
- Use parallax separation: foreground fastest, subject near 1.0, distant architecture slower, sky nearly static.
- Use slots such as {SPEAKER}, {LINE}, {PLACE}, {REGION}, {WITNESS_NAME}, and {RECORD_STATUS}.
- Use events for gameplay synchronization: IMPACT, CHOICE_LOCKED, RECORD_SAVED, WITNESS_REVEALED.
- Use Sequence branching for alternate outcomes rather than duplicating entire projects.
- Prefer short scenes. Build the first version, then remove roughly one-third of the runtime.
- Save reusable dialogue, location reveal, archive overlay, impact, and reward shots to the shot library.

## Tags
`production`, `Cutscene Builder`, `variables`, `events`
