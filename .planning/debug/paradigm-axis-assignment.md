---
status: verifying
trigger: "paradigm-axis-assignment"
created: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

## Current Focus

hypothesis: paradigmAxesProvider computes defaultsFor(ALL dims including intrinsic), assigning intrinsic dim to rows axis. _IntrinsicSliceTable then fails to resolve rowDim (it is intrinsic, filtered from nonIntrinsicDims), falls back to nonIntrinsicDims[0] for rowDim — but colDim was already set to nonIntrinsicDims[1] from axes.cols, so BOTH row and col end up pointing to the same non-intrinsic dim (e.g. Number). Case lands in tabs so it renders as stacked separate tables.
test: Trace paradigmAxesProvider fallback → defaultsFor(dims) with dims=[Animacy(intrinsic), Number, Case] → rows=Animacy.id, cols=Number.id. Then _IntrinsicSliceTable: rowDim lookup for Animacy.id in nonIntrinsicDims → null; colDim lookup for Number.id → Number. Fallback: rowDim=nonIntrinsicDims[0]=Number, colDim stays Number. Both axes = Number.
expecting: Fix: filter intrinsic dims before passing to defaultsFor inside paradigmAxesProvider
next_action: Human verification — confirm paradigm table shows Number rows × Case cols per intrinsic slice

## Symptoms

expected: One table per intrinsic level (Animate, Inanimate, Abstract). Each table: Number as rows × Case as columns (the two non-intrinsic dimensions).
actual: Number (sg/pl) on BOTH row and column axes. Case (nom/gen) as separate stacked tables.
errors: No errors — just incorrect axis assignment logic
reproduction: Create a language with 3 grammatical dimensions: Animacy (intrinsic), Number (sg/pl), Case (nom/gen). View the paradigm table.
started: Pre-existing bug discovered during UAT

## Eliminated

- hypothesis: Bug in _IntrinsicSliceTable fallback logic assigning wrong default dims
  evidence: The fallback at line 1253 (rowDim ??= nonIntrinsicDims[0]) is correct IF colDim were null. The real problem is upstream: colDim is non-null (resolved from axes.cols=Number.id), so the if-block's null-check for rowDim does fire but colDim is NOT reassigned to nonIntrinsicDims[1]. Result: both = Number.
  timestamp: 2026-04-13T00:00:00Z

## Evidence

- timestamp: 2026-04-13T00:00:00Z
  checked: paradigmAxesProvider fallback in typology_providers.dart lines 357-368
  found: When no stored axes config exists, calls ParadigmAxes.defaultsFor(dims) where dims = ALL dimensions for the POS including intrinsic ones. With dims=[Animacy(intrinsic,ordering=0), Number(ordering=1), Case(ordering=2)] this produces rows=Animacy.id, cols=Number.id, tabs=[Case.id].
  implication: The stored/computed axes have rows pointing at an intrinsic dim id.

- timestamp: 2026-04-13T00:00:00Z
  checked: _IntrinsicSliceTable.build() lines 1244-1258
  found: rowDim resolved as nonIntrinsicDims.where((d) => d.id == axes.rows) — Animacy is intrinsic so not in nonIntrinsicDims → rowDim = null. colDim resolved as nonIntrinsicDims.where((d) => d.id == axes.cols) → Number found, colDim = Number. Fallback: since rowDim == null, rowDim = nonIntrinsicDims[0] = Number. colDim is already set so not overwritten. Final: rowDim=Number, colDim=Number.
  implication: Both axes point to Number, causing Number to appear on both row and col headers.

- timestamp: 2026-04-13T00:00:00Z
  checked: extraDims computation at line 1261
  found: extraDims = nonIntrinsicDims.where(d.id != rowDim.id && d.id != colDim.id) — since rowDim=colDim=Number, Case is NOT filtered and becomes an extra dim, generating stacked sub-tables.
  implication: Case renders as stacked tables instead of columns.

## Resolution

root_cause: paradigmAxesProvider's default fallback passes ALL dimensions (including intrinsic) to ParadigmAxes.defaultsFor(). This assigns the intrinsic dim (e.g. Animacy) as the rows axis id. When _IntrinsicSliceTable resolves row/col dims, it only searches nonIntrinsicDims — so rowDim comes back null. The null-fallback assigns nonIntrinsicDims[0] (Number) to rowDim, but colDim was already set to Number from axes.cols. Both axes end up as Number; Case falls into extra/tabs and renders as stacked tables.
fix: In paradigmAxesProvider, filter out intrinsic dimensions before calling ParadigmAxes.defaultsFor(). This ensures the default axes only reference non-intrinsic dims: rows=Number, cols=Case, tabs=[].
verification: Fix applied to both readParadigmAxes (line 150) and paradigmAxesProvider (line 368) in typology_providers.dart. Both now call defaultsFor with intrinsic dims filtered out.
files_changed:
  - lib/features/grammar/data/typology_providers.dart
