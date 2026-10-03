# Bot personality portrait atlas

- Production file: `bot-personality-atlas.png`.
- Created: 2026-09-20 with the built-in OpenAI image-generation tool.
- Dimensions: 1280 x 1024 RGBA PNG, five portraits per row in four rows.
  Generated spacing is irregular; runtime rendering uses measured portrait
  bounds in `lib/src/features/online/avatar_portrait_regions.dart`.
- SHA-256: `6c693157ac5e59331007f2ef02f8a53f3959fa08150babc1fafb5175209f523c`.
- Project license: GPL-3.0-or-later.
- Runtime mapping: the 20 entries in `builtInComputerOpponents`, in row-major
  order. The independent 50-portrait human avatar picker is unchanged.

## Identity direction

| Cell | Bot | Fictional nationality brief | Personality direction |
| ---: | --- | --- | --- |
| 1 | Amina Diallo | Senegalese | Curious, sunny, encouraging beginner |
| 2 | Lucas Martin | French | Relaxed, playful, approachable beginner |
| 3 | Mei Lin | Chinese | Thoughtful, studious, gentle beginner |
| 4 | Omar Haddad | Lebanese | Warm, patient, good-humored beginner |
| 5 | Sofia Rossi | Italian | Lively, friendly, spontaneous beginner |
| 6 | Kwame Mensah | Ghanaian | Cheerful, calm, encouraging beginner |
| 7 | Ana Costa | Portuguese | Composed, sociable, observant beginner |
| 8 | Priya Nair | Indian, Kerala | Focused, resourceful, quietly competitive |
| 9 | Diego Alvarez | Mexican | Energetic, bold, tactical intermediate |
| 10 | Haruto Sato | Japanese | Precise, courteous, intensely focused |
| 11 | Nadia Petrova | Bulgarian | Cool-headed, methodical, resilient |
| 12 | Thandi Ndlovu | South African, Zulu | Confident, perceptive, upbeat |
| 13 | Noah Williams | British | Patient, analytical, understated |
| 14 | Fatima Zahra | Moroccan | Serene, strategic, empathetic |
| 15 | Arjun Mehta | Indian | Disciplined, calculating advanced player |
| 16 | Elena Popescu | Romanian | Poised, formidable, sophisticated |
| 17 | Mateo Silva | Brazilian | Charismatic, fearless, creative |
| 18 | Min Jun | South Korean | Composed, ingenious, quietly intense |
| 19 | Emma Clarke | British | Confident, witty, highly analytical |
| 20 | Ivan Petrov | Russian | Stern, sportsmanlike, patient, commanding |

These nationalities are fictional creative direction inferred from the names;
they are not claims about real people. Contemporary styling, varied facial
features, grooming, complexion, and expression communicate identity without
flags, landmarks, caricature, ceremonial dress, or exaggerated stereotypes.

## Final generation prompt

```text
Use case: stylized-concept
Asset type: production mobile-game avatar sprite atlas for exactly 20 fictional computer chess opponents.
Primary request: create exactly 20 distinct contemporary human head-and-shoulders portraits in an exact 5-column by 4-row grid. Every cell is equal and square, with one centered portrait at consistent scale and eye line, safe hair and shoulder padding for circular cropping, a simple soft-color circular backdrop, and transparent gutters. Polished premium 2D game-avatar illustration, crisp contours, warm natural skin rendering, bright even lighting, expressive but restrained faces. No text or labels; follow the exact row-major identity order documented above.
Rows 1–2: friendly beginner personalities—Amina, Lucas, Mei, Omar, Sofia, Kwame and Ana—followed by focused intermediate Priya, Diego and Haruto. Row 3: methodical intermediate Nadia, Thandi, Noah and Fatima, followed by disciplined advanced Arjun. Row 4: advanced competitors Elena, Mateo, Min Jun, Emma and Ivan. Match each portrait to the documented nationality, age, grooming, contemporary clothing palette and personality direction.
Cultural direction: communicate nationality primarily through plausible facial features, complexion, grooming, and contemporary personal style. Avoid flags, landmarks, national symbols, caricature, exaggerated ethnicity, historical dress, ceremonial costume, and religious symbols except Fatima's ordinary modern hijab.
Grid constraints: exactly 5 columns and 4 rows; exactly 20 portraits; one person per cell; consistent front-facing or very slight three-quarter pose; faces occupy the same relative size; no overlap or empty cells.
Avoid: chess pieces, crowns, armor, fantasy costumes, uniforms, weapons, hands covering faces, duplicate faces, children, elderly people, photorealism, text, initials, numbers, logos, watermarks, borders, grid lines, checkerboards, scenery, cropped chins, cropped hair, malformed glasses, asymmetrical eyes, or extra people.
Output: one finished atlas with genuine transparent outer background and gutters.
```
