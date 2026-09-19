# PrFitness Phase 11 — Accuracy, Offline Food Intelligence, Edit & Undo

## Energy accounting

The selected overall activity level is already represented in the baseline TDEE / calorie target. Logged activity calories are therefore displayed as an informational estimate and are not added back into the food budget. The remaining food budget is:

`baseline calorie target - food intake`

This prevents exercise double counting.

## Offline food intelligence

PrFitness includes a local searchable starter food catalog, custom foods, favourites, recent items, meal categories and deterministic serving-size nutrition scaling. Nutrition math is based on per-100 g values and the actual entered serving mass.

The bundled values are convenience reference data, not medical or dietetic advice. User-defined foods remain available for label-specific nutrition values.

## Edit and undo

Food, activity, hydration, study, body weight, goals, routines and reminders can be corrected through a central data-management surface. Deletes expose a short undo action. Database triggers from Phase 9 automatically convert edits and restored records into sync outbox updates.

## History Vault+

The upgraded history surface adds search, category filters, details, quick repeat for common tracked actions and direct access to edit/undo controls.