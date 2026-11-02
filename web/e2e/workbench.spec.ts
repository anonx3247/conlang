import { expect, test, type Page } from '@playwright/test';

const SHOTS = process.env.SHOTS_DIR;
const shot = async (page: Page, name: string) => {
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/${name}.png` });
};

// Falls back to browser storage so the native file picker doesn't block the run.
test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    delete (window as unknown as Record<string, unknown>).showSaveFilePicker;
    delete (window as unknown as Record<string, unknown>).showOpenFilePicker;
  });
});

async function newProject(page: Page, name: string) {
  await page.goto('/');
  await page.getByRole('button', { name: 'New Project' }).click();
  await page.getByLabel('Project name').fill(name);
  await page.getByRole('button', { name: 'Create' }).click();
  await expect(page.getByTestId('project-name')).toHaveText(name);
}

async function addPhoneme(page: Page, symbol: string, latin = symbol) {
  await page.getByRole('button', { name: 'Add Phoneme' }).click();
  await page.getByLabel('IPA Symbol (optional)').fill(symbol);
  await page.locator('.dialog').getByRole('button', { name: 'Add', exact: true }).click();
  await page.getByLabel('Latin representation').fill(latin);
  await page.getByRole('dialog', { name: /Add romanization/ }).getByRole('button', { name: 'Add', exact: true }).click();
  await expect(page.locator('.dialog')).toHaveCount(0);
}

async function addPos(page: Page, name: string, abbr: string) {
  await page.getByRole('button', { name: 'Add POS' }).click();
  await page.getByLabel('Name', { exact: true }).fill(name);
  await page.getByLabel('Abbreviation').fill(abbr);
  await page.locator('.dialog').getByRole('button', { name: 'Add', exact: true }).click();
}

async function addDerivation(page: Page, name: string, input: string, output: string, affix: string) {
  await page.getByRole('button', { name: 'Add Rule' }).click();
  await page.getByLabel('Rule name').fill(name);
  await page.getByLabel('Input POS').selectOption({ label: input });
  await page.getByLabel('Output POS').selectOption({ label: output });
  await page.getByLabel('Affix').fill(affix);
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.locator('.dialog')).toHaveCount(0);
}

test('full workflow: phonology to scratchpad, derivations stay correct everywhere', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

  await page.goto('/');
  await expect(page.getByText('Conlang Workbench', { exact: true })).toBeVisible();
  await shot(page, '01-welcome');
  await newProject(page, 'Kalish');

  // Phonology
  for (const [s, l] of [['k', 'k'], ['l', 'l'], ['t', 't'], ['m', 'm'], ['ʃ', 'sh'], ['a', 'a'], ['o', 'o'], ['i', 'i']]) await addPhoneme(page, s, l);
  await expect(page.getByTestId('phoneme-ʃ').first()).toContainText('sh');
  await shot(page, '02-inventory');

  await page.getByRole('link', { name: 'Sound Rules' }).click();
  await page.getByTestId('add-template').click();
  await page.getByLabel('Template: add class').selectOption('C');
  await page.getByLabel('Template: add class').selectOption('V');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('CV', { exact: true })).toBeVisible();
  await expect(page.getByTestId('generated-words')).not.toContainText('Define templates');

  await page.getByTestId('add-rewrite').click();
  await page.getByLabel('Pattern: add sound').fill('t');
  await page.getByLabel('Pattern: add sound').press('Enter');
  await page.getByLabel('Replacement (phonetic)').fill('d');
  await page.getByLabel('Before: add class').selectOption('V');
  await page.getByLabel('After: add class').selectOption('V');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('t → d / V_V')).toBeVisible();
  await shot(page, '03-sound-rules');

  // Grammar
  await page.getByRole('button', { name: 'Grammar' }).click();
  await addPos(page, 'Verb', 'v');
  await addPos(page, 'Noun', 'n');
  await addPos(page, 'Adjective', 'adj');
  await page.getByTestId('pos-Noun').click();
  await page.getByRole('button', { name: 'Add Dimension' }).click();
  await page.locator('.dialog').getByText('Singular / Plural', { exact: true }).click();
  await expect(page.getByTestId('dimension-Singular / Plural')).toBeVisible();
  await shot(page, '04-pos');

  // Lexicon rules, including the v -> n -> adj chain from the original bug report
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await page.getByRole('link', { name: 'Derivations' }).click();
  await addDerivation(page, 'Nominal', 'Verb (v.)', 'Noun (n.)', 'a');
  await addDerivation(page, 'Adjectival', 'Noun (n.)', 'Adjective (adj.)', 'o');
  await page.getByRole('link', { name: 'Dictionary' }).click();
  await page.getByRole('button', { name: 'New word' }).click();
  await page.getByLabel('Romanization *').fill('kal');
  await page.getByLabel('Meaning').fill('to run');
  await page.getByLabel('Part of speech *').selectOption({ label: 'Verb' });
  await shot(page, '05-new-word');
  await page.getByRole('button', { name: 'New word' }).nth(1).click();
  await expect(page.getByTestId('word-form')).toHaveText('kal');

  await page.getByLabel('Meaning for kala').fill('runner');
  await page.getByLabel('Meaning for kala').press('Enter');
  await page.getByTestId('derived-Nominal').getByTestId('derived-form').click();
  await expect(page.getByTestId('word-form')).toHaveText('kala');
  await expect(page.getByTestId('derived-Adjectival').getByTestId('derived-form')).toContainText('kalao');
  await page.getByLabel('Meaning for kalao').fill('runner-like');
  await page.getByLabel('Meaning for kalao').press('Enter');
  await page.getByTestId('derived-Adjectival').getByTestId('derived-form').click();
  await expect(page.getByTestId('word-form')).toHaveText('kalao');
  await expect(page.getByTestId('derived-via')).toContainText('Nominal → Adjectival');
  await expect(page.getByTestId('etymology').getByTestId('pill-form').first()).toHaveText('kal');
  await shot(page, '06-word-detail');
  await expect(page.getByTestId('word-list')).toContainText('kalao');
  await expect(page.getByTestId('word-count')).toHaveText('3 words');

  // Search finds a word by its derived form, not a stored placeholder
  await page.getByLabel('Search words').fill('kalao');
  await expect(page.getByTestId('word-count')).toHaveText('2 words');
  await page.getByLabel('Search words').fill('');

  // Inflection on a derived word starts from the derived form
  await page.getByRole('button', { name: 'Grammar' }).click();
  await page.getByRole('link', { name: 'Inflections' }).click();
  await page.getByLabel('POS', { exact: true }).selectOption({ label: 'Noun' });
  await page.locator('[data-testid^="cell-"]').nth(1).click();
  await page.getByLabel('Rule name').fill('Plural');
  await page.getByLabel('Affix').fill('ti');
  await expect(page.getByTestId('rule-preview')).toContainText('ti');
  await shot(page, '07-rule-editor');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.locator('[data-testid^="cell-"]').nth(1)).toContainText('kalati');
  // Rewrite shows in brackets; romanization stays phonemic.
  await expect(page.locator('[data-testid^="cell-"]').nth(1)).toContainText('[kaladi]');
  await shot(page, '08-inflections');

  // Word-level override
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await page.getByTestId('word-kala').click();
  await page.getByTestId('word-paradigm').locator('[data-testid^="cell-"]').first().click();
  await page.locator('.dialog').getByLabel('Romanization').fill('kalu');
  await page.locator('.dialog').getByRole('button', { name: 'Save Override' }).click();
  await expect(page.getByTestId('word-paradigm').locator('[data-testid^="cell-"]').first()).toContainText('kalu');

  // Particles and constructions
  await page.getByRole('button', { name: 'New word' }).click();
  await page.getByLabel('Romanization *').fill('mo');
  await page.getByRole('radio', { name: 'Gloss only' }).click();
  await page.getByLabel('Gloss tag').fill('NEG');
  await page.getByRole('button', { name: 'New word' }).nth(1).click();
  await expect(page.getByTestId('word-mo')).toContainText('mo (p.)');
  await expect(page.getByTestId('word-mo')).toContainText('NEG');
  await page.getByRole('button', { name: 'Grammar' }).click();
  await page.getByRole('link', { name: 'Constructions' }).click();
  await page.getByRole('button', { name: 'Add Construction' }).click();
  await page.getByRole('button', { name: 'Add Slot' }).click();
  await page.getByLabel('Find a word').fill('mo');
  await page.getByRole('button', { name: 'mo — NEG' }).click();
  await page.getByRole('button', { name: 'Add', exact: true }).click();
  await page.getByRole('button', { name: 'Add Slot' }).click();
  await page.getByRole('radio', { name: 'Part of Speech' }).click();
  await page.getByLabel('Part of Speech', { exact: true }).selectOption({ label: 'Verb (v)' });
  await page.getByRole('button', { name: 'Add', exact: true }).click();
  await expect(page.getByTestId('construction-preview')).toHaveText('mo kal');
  await shot(page, '09-constructions');
  await page.getByRole('link', { name: 'Typology' }).click();
  await page.getByLabel('Alignment').selectOption({ label: 'Ergative-Absolutive' });

  // Scratchpad reads surface forms, and reloading keeps everything
  await page.getByRole('button', { name: 'Scratchpad' }).click();
  await page.getByRole('button', { name: 'New Phrase' }).click();
  await page.getByLabel('Phrase', { exact: true }).fill('mo kalati kalao zzz.');
  await expect(page.getByTestId('gloss')).toHaveText(['NEG', 'runner.PL', 'runner-like', '?']);
  await page.getByLabel('Free translation').fill('a test');
  await page.getByRole('button', { name: '/aɪ/' }).click();
  await expect(page.getByTestId('token-ipa').nth(1)).toHaveText('/kaladi/');
  await shot(page, '10-scratchpad');
  await page.waitForTimeout(1300);
  await page.reload();
  await expect(page.getByTestId('project-name')).toHaveText('Kalish');
  await page.getByRole('button', { name: 'Scratchpad' }).click();
  await page.getByTestId('phrase-list').getByText('mo kalati kalao zzz.').click();
  await expect(page.getByLabel('Free translation')).toHaveValue('a test');

  // References and glossary
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await page.getByRole('link', { name: 'Swadesh List' }).click();
  await expect(page.getByTestId('swadesh-coverage')).toContainText('/207');
  await page.getByRole('link', { name: 'Thesaurus' }).click();
  await page.getByLabel('Search concepts').fill('comet');
  await expect(page.getByTestId('thesaurus')).toContainText('comet');
  await page.getByRole('button', { name: 'Name this concept' }).first().click();
  await expect(page.getByLabel('Meaning')).toHaveValue('comet');
  await page.getByRole('button', { name: 'Cancel', exact: true }).click();
  await page.getByRole('button', { name: 'Glossary', exact: true }).click();
  await page.getByLabel('Search terms').fill('allophone');
  await expect(page.getByTestId('glossary')).toContainText('allophone');
  await shot(page, '11-glossary');

  // Deleting the parent freezes its derived words at their current forms
  await page.getByRole('button', { name: 'Close glossary' }).click();
  await page.getByRole('link', { name: 'Dictionary' }).click();
  await page.getByTestId('word-kal').click();
  await page.getByRole('button', { name: 'Delete word' }).click();
  await page.locator('.dialog').getByRole('button', { name: 'Delete' }).click();
  await expect(page.getByTestId('word-list')).toContainText('kalao');
  await expect(page.getByTestId('word-count')).toHaveText('3 words');

  // File menu
  await page.getByTestId('menu-file').click();
  await page.getByRole('menuitem', { name: 'Close Project' }).click();
  await expect(page.getByText('Recent Projects')).toBeVisible();
  await page.getByText('Kalish').click();
  await expect(page.getByTestId('project-name')).toHaveText('Kalish');

  expect(errors).toEqual([]);
});

async function newWord(page: Page, form: string, kind: { meaning: string; pos: string } | { tag: string }) {
  await page.getByRole('button', { name: 'New word' }).click();
  await page.getByLabel('Romanization *').fill(form);
  if ('tag' in kind) {
    await page.getByRole('radio', { name: 'Gloss only' }).click();
    await page.getByLabel('Gloss tag').fill(kind.tag);
  } else {
    await page.getByLabel('Meaning').fill(kind.meaning);
    await page.getByLabel('Part of speech *').selectOption({ label: kind.pos });
  }
  await page.getByRole('button', { name: 'New word' }).nth(1).click();
  await expect(page.getByTestId('word-form')).toHaveText(form);
}

async function wordSlot(page: Page, search: string, option: string, tag?: string) {
  await page.getByRole('button', { name: 'Add Slot' }).click();
  await page.getByLabel('Find a word').fill(search);
  await page.getByRole('button', { name: option }).click();
  if (tag) await page.getByLabel('Gloss tag (optional)').fill(tag);
  await page.getByRole('button', { name: 'Add', exact: true }).click();
}

async function typePhrase(page: Page, text: string) {
  await page.getByLabel('Phrase', { exact: true }).fill(text);
  await page.waitForTimeout(350);
}

test('particles live in the lexicon and constructions gloss phrases', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await newProject(page, 'Slots');
  for (const s of ['k', 'l', 't', 'm', 'n', 'a', 'o', 'i', 'u']) await addPhoneme(page, s);

  // The Grammar sidebar has no Particles tab, and the first item is renamed.
  await page.getByRole('button', { name: 'Grammar' }).click();
  await expect(page.getByRole('link', { name: 'Parts of Speech' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Particles' })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'POS & Dimensions' })).toHaveCount(0);
  await addPos(page, 'Verb', 'v');
  await addPos(page, 'Noun', 'n');
  await page.getByTestId('pos-Noun').click();
  await page.getByRole('button', { name: 'Add Dimension' }).click();
  await page.locator('.dialog').getByText('Singular / Plural', { exact: true }).click();
  await page.getByRole('link', { name: 'Inflections' }).click();
  await page.getByLabel('POS', { exact: true }).selectOption({ label: 'Noun' });
  await page.locator('[data-testid^="cell-"]').nth(1).click();
  await page.getByLabel('Rule name').fill('Plural');
  await page.getByLabel('Affix').fill('ti');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();

  // Words and particles share the New Word form
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await newWord(page, 'tala', { meaning: 'to have', pos: 'Verb' });
  await newWord(page, 'kal', { meaning: 'stone', pos: 'Noun' });
  await newWord(page, 'mo', { tag: 'NEG' });
  await expect(page.getByTestId('word-tag')).toHaveText('NEG');
  await expect(page.getByTestId('word-mo')).toContainText('mo (p.)');
  await expect(page.getByTestId('word-mo').getByTestId('word-gloss')).toHaveText('NEG');

  // A shared tag warns and doesn't block
  await page.getByRole('button', { name: 'New word' }).click();
  await page.getByLabel('Romanization *').fill('nu');
  await page.getByRole('radio', { name: 'Gloss only' }).click();
  await page.getByLabel('Gloss tag').fill('neg');
  await expect(page.getByTestId('tag-warning')).toContainText('mo already has this tag');
  await shot(page, '30-gloss-only-form');
  await page.getByRole('button', { name: 'New word' }).nth(1).click();
  await expect(page.getByTestId('word-form')).toHaveText('nu');

  // The Particles chip
  await expect(page.getByTestId('word-count')).toHaveText('4 words');
  await page.getByRole('button', { name: 'Particles', exact: true }).click();
  await expect(page.getByTestId('word-count')).toHaveText('2 words');
  await shot(page, '31-dictionary-particles');
  await page.getByRole('button', { name: 'All', exact: true }).click();
  await expect(page.getByTestId('word-count')).toHaveText('4 words');

  // A word can be flipped later, both ways
  await page.getByRole('button', { name: 'Edit word' }).click();
  await page.getByRole('radio', { name: 'Meaning' }).click();
  await page.getByLabel('Meaning').fill('not at all');
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(page.getByTestId('word-nu').getByTestId('word-gloss')).toHaveText('not at all');
  await page.getByRole('button', { name: 'Edit word' }).click();
  await page.getByRole('radio', { name: 'Gloss only' }).click();
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(page.getByLabel('Gloss tag')).toBeVisible();
  await page.getByLabel('Gloss tag').fill('EMPH');
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(page.getByTestId('word-nu').getByTestId('word-gloss')).toHaveText('EMPH');

  // Past: tala [PST] + Phrase
  await page.getByRole('button', { name: 'Grammar' }).click();
  await page.getByRole('link', { name: 'Constructions' }).click();
  await page.getByRole('button', { name: 'Add Construction' }).click();
  await page.getByLabel('Construction name').fill('Past');
  await page.getByLabel('Construction name').blur();
  await wordSlot(page, 'tala', 'tala — to have', 'PST');
  await page.getByRole('button', { name: 'Add Slot' }).click();
  await page.getByRole('radio', { name: 'Phrase' }).click();
  await page.getByRole('button', { name: 'Add', exact: true }).click();
  await expect(page.getByTestId('construction-preview')).toHaveText('tala [phrase]');

  // Negation: mo + Noun (Plural), with the form picker
  await page.getByRole('button', { name: 'Add Construction' }).click();
  await page.getByLabel('Construction name').fill('Negation');
  await page.getByLabel('Construction name').blur();
  await wordSlot(page, 'mo', 'mo — NEG');
  await page.getByRole('button', { name: 'Add Slot' }).click();
  await page.getByRole('radio', { name: 'Part of Speech' }).click();
  await expect(page.getByTestId('form-picker')).toHaveCount(0);
  await page.getByLabel('Part of Speech', { exact: true }).selectOption({ label: 'Noun (n)' });
  await page.getByTestId('form-picker').getByRole('combobox').selectOption({ label: 'Plural' });
  await shot(page, '32-slot-form');
  await page.getByRole('button', { name: 'Add', exact: true }).click();
  await expect(page.getByTestId('construction-preview')).toHaveText('mo kalti');
  await shot(page, '33-constructions');

  // A construction with no Word slot warns
  await page.getByRole('button', { name: 'Add Construction' }).click();
  await page.getByRole('button', { name: 'Add Slot' }).click();
  await page.getByRole('radio', { name: 'Clause' }).click();
  await page.getByLabel('Label (optional)').fill('subjunctive clause');
  await page.getByRole('button', { name: 'Add', exact: true }).click();
  await expect(page.getByTestId('construction-warnings')).toContainText('at least one Word slot');
  await expect(page.getByTestId('construction-preview')).toHaveText('[subjunctive clause]');

  // The scratchpad applies them
  await page.getByRole('button', { name: 'Scratchpad' }).click();
  await page.getByRole('button', { name: 'New Phrase' }).click();
  await typePhrase(page, 'tala kal kal');
  await expect(page.getByTestId('gloss')).toHaveText(['PST', 'stone', 'stone']);
  await expect(page.getByTestId('construction-name')).toHaveText(['Past']);
  await typePhrase(page, 'tala');
  await expect(page.getByTestId('gloss')).toHaveText(['to have']);
  await expect(page.getByTestId('construction-name')).toHaveCount(0);
  await typePhrase(page, 'kal mo kalti tala kal');
  await expect(page.getByTestId('gloss')).toHaveText(['stone', 'NEG', 'stone.PL', 'PST', 'stone']);
  await expect(page.getByTestId('construction-name')).toHaveText(['Negation', 'Past']);
  await shot(page, '34-scratchpad-constructions');
  await typePhrase(page, 'mo kal');
  await expect(page.getByTestId('gloss')).toHaveText(['NEG', 'stone']);
  await expect(page.getByTestId('construction-name')).toHaveCount(0);

  // Word pages list constructions; deleting warns and marks the slot missing
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await page.getByTestId('word-mo').click();
  await expect(page.getByTestId('word-constructions')).toContainText('Negation');
  await page.getByRole('button', { name: 'Delete word' }).click();
  await expect(page.getByTestId('slot-use-warning')).toContainText('Negation');
  await shot(page, '35-delete-warning');
  await page.locator('.dialog').getByRole('button', { name: 'Delete' }).click();
  await page.getByRole('button', { name: 'Grammar' }).click();
  await page.getByRole('link', { name: 'Constructions' }).click();
  await page.getByText('Negation', { exact: true }).click();
  await expect(page.getByTestId('construction-preview')).toContainText('(missing word: mo)');
  await expect(page.getByTestId('construction-warnings')).toContainText('The word mo is missing');
  await shot(page, '36-missing-slot');
  // ...and the slot can be pointed at another word
  await page.getByTestId('slot-0').getByRole('button', { name: 'Edit slot' }).click();
  await page.getByLabel('Find a word').fill('nu');
  await page.getByRole('button', { name: 'nu — EMPH' }).click();
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(page.getByTestId('construction-preview')).toHaveText('nu kalti');
  await expect(page.getByTestId('construction-warnings')).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('an inflection can lengthen a vowel and geminate a consonant', async ({ page }) => {
  await newProject(page, 'Long');
  for (const s of ['k', 't', 'a', 'i']) await addPhoneme(page, s);
  await page.getByRole('button', { name: 'Grammar' }).click();
  await addPos(page, 'Noun', 'n');
  await page.getByTestId('pos-Noun').click();
  await page.getByRole('button', { name: 'Add Dimension' }).click();
  await page.locator('.dialog').getByText('Singular / Plural', { exact: true }).click();
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await newWord(page, 'kati', { meaning: 'stone', pos: 'Noun' });
  await page.getByRole('button', { name: 'Grammar' }).click();
  await page.getByRole('link', { name: 'Inflections' }).click();
  await page.getByLabel('POS', { exact: true }).selectOption({ label: 'Noun' });
  await page.locator('[data-testid^="cell-"]').nth(1).click();
  await page.getByLabel('Rule name').fill('Plural');
  await page.getByLabel('Operation type').selectOption({ label: 'Elongation (long vowel or geminate)' });
  // Only the three positions are offered, never "all".
  await expect(page.getByLabel('Which one').locator('option')).toHaveText(['first', 'second', 'third']);
  await expect(page.getByTestId('long-vowel-note')).toContainText('aː, iː');
  await page.getByLabel('Which one').selectOption({ label: 'second' });
  await page.getByRole('button', { name: 'Add operation' }).click();
  await page.getByLabel('Operation type').nth(1).selectOption({ label: 'Elongation (long vowel or geminate)' });
  await page.getByLabel('Sound to elongate').nth(1).selectOption({ label: 'consonant' });
  await page.getByLabel('Direction').nth(1).selectOption({ label: 'from end' });
  await expect(page.getByTestId('rule-preview')).toContainText('kattiː');
  await shot(page, '38-elongation');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.locator('[data-testid^="cell-"]').nth(1)).toContainText('kattiː');
});

test('geminate and long vowel are built-in classes that phonotactic rules can use', async ({ page }) => {
  await newProject(page, 'Lengths');
  for (const s of ['k', 't', 'a', 'i']) await addPhoneme(page, s);
  await page.getByRole('link', { name: 'Natural Classes' }).click();
  await expect(page.getByTestId('class-geminate')).toContainText('any consonant');
  await expect(page.getByTestId('class-long vowel')).toContainText('any vowel');
  await page.getByRole('link', { name: 'Sound Rules' }).click();
  await page.getByTestId('add-constraint').click();
  await page.getByText('Forbidden sequence', { exact: true }).last().click();
  await page.getByLabel('Forbidden pattern: add class').selectOption('geminate');
  await page.getByLabel('Forbidden pattern: add class').selectOption('geminate');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('[geminate][geminate]').first()).toBeVisible();
  await shot(page, '39-length-class-constraint');
  await page.getByRole('button', { name: 'Grammar' }).click();
  await addPos(page, 'Noun', 'n');
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await newWord(page, 'kattkki', { meaning: 'stone', pos: 'Noun' });
  await expect(page.getByTestId('word-phonetic').locator('.viol')).toHaveText('ttkk');
  await newWord(page, 'kattaki', { meaning: 'river', pos: 'Noun' });
  await expect(page.getByTestId('word-phonetic').locator('.viol')).toHaveCount(0);
});

test('an older project file is upgraded, and what changed is reported once', async ({ page }) => {
  await page.goto('/');
  const word = (id: number, phonemic: string, meaning: string | null, glossTag: string | null) => ({ id, form: { kind: 'root', phonemic }, meaning, posId: null, isException: false, rootOnly: false, isClosedClass: true, glossTag, skippedDimensionIds: [], intrinsicLevels: {} });
  const v1 = {
    format: 'conlang-workbench', version: 1, name: 'Oldie', createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-01T00:00:00.000Z', nextId: 100,
    partsOfSpeech: [{ id: 1, name: 'Verb', abbr: 'v' }],
    lexemes: [word(2, 'mo', null, 'NEG'), word(3, 'al', 'to', 'PREP')],
    constructions: [{ id: 4, name: 'Future', order: 0, slots: [{ id: 5, type: 'gloss_tag', value: 'FUT' }, { id: 6, type: 'pos', value: '1' }] }],
  };
  const chooser = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Open Project' }).click();
  await (await chooser).setFiles({ name: 'Oldie.conlang.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(v1)) });
  await expect(page.getByTestId('report')).toContainText('al "to": the gloss tag PREP was dropped');
  await expect(page.getByTestId('report')).toContainText('no word has the tag FUT');
  await shot(page, '37-upgrade-report');
  await page.getByRole('button', { name: 'OK' }).click();
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await expect(page.getByTestId('word-mo')).toContainText('mo (p.)');
  await expect(page.getByTestId('word-al').getByTestId('word-gloss')).toHaveText('to');
  // Saved in the new format, so it doesn't come up again.
  await page.waitForTimeout(600);
  await page.reload();
  await expect(page.getByTestId('project-name')).toHaveText('Oldie');
  await expect(page.getByTestId('report')).toHaveCount(0);
  await page.getByRole('button', { name: 'Grammar' }).click();
  await page.getByRole('link', { name: 'Constructions' }).click();
  await expect(page.getByTestId('construction-preview')).toContainText('(missing word: FUT)');
});

test('imports a legacy SQLite project and JSON files through the file dialog', async ({ page }) => {
  test.skip(!process.env.LEGACY_FILE, 'set LEGACY_FILE to a .conlang file to run');
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto('/');
  const chooser = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Open Project' }).click();
  await (await chooser).setFiles(process.env.LEGACY_FILE!);
  await expect(page.getByTestId('project-name')).toBeVisible({ timeout: 15000 });
  // Ashakin's al has a meaning and an unused tag, and its FUT slot has no word.
  await expect(page.getByTestId('report')).toContainText('PREP was dropped');
  await expect(page.getByTestId('report')).toContainText('no word has the tag FUT');
  await page.getByRole('button', { name: 'OK' }).click();
  await shot(page, '20-legacy-inventory');
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await expect(page.getByTestId('word-count')).not.toHaveText('0 words');
  await page.getByTestId('word-dairenor').click();
  await expect(page.getByTestId('word-form')).toHaveText('dairenor');
  await expect(page.getByTestId('derived-via')).toContainText('Denominal → Actor');
  await shot(page, '21-legacy-word');
  await page.getByRole('button', { name: 'Grammar' }).click();
  await page.getByRole('link', { name: 'Inflections' }).click();
  await page.getByLabel('POS', { exact: true }).selectOption({ index: 1 });
  await shot(page, '22-legacy-inflections');
  await page.getByRole('button', { name: 'Scratchpad' }).click();
  expect(errors).toEqual([]);
});

test('a linked project file is kept in sync both ways, as the MCP server relies on', async ({ browser }) => {
  // The origin-private file system stands in for a user-picked file: same API, no native dialog.
  const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  const page = await context.newPage();
  await page.addInitScript(() => {
    (window as unknown as { showSaveFilePicker: unknown }).showSaveFilePicker = async ({ suggestedName }: { suggestedName: string }) => (await navigator.storage.getDirectory()).getFileHandle(suggestedName, { create: true });
  });
  await page.goto('/');
  await page.getByRole('button', { name: 'New Project' }).click();
  await page.getByLabel('Project name').fill('Synced');
  await page.getByRole('button', { name: 'Create' }).click();
  await expect(page.getByTestId('project-name')).toHaveText('Synced');

  await page.getByRole('button', { name: 'Grammar' }).click();
  await addPos(page, 'Noun', 'n');
  const read = () => page.evaluate(async () => {
    const h = await (await navigator.storage.getDirectory()).getFileHandle('Synced.conlang.json');
    return (await h.getFile()).text();
  });
  await expect.poll(async () => JSON.parse(await read()).partsOfSpeech.length).toBe(1);
  await expect.poll(read).not.toContain('sqlite');

  // Simulates the MCP server adding a word to the file.
  await page.waitForTimeout(100);
  await page.evaluate(async () => {
    const h = await (await navigator.storage.getDirectory()).getFileHandle('Synced.conlang.json');
    const doc = JSON.parse(await (await h.getFile()).text());
    doc.lexemes.push({ id: 500, form: { kind: 'root', phonemic: 'zomu' }, meaning: 'from the ai', posId: doc.partsOfSpeech[0].id, isException: false, rootOnly: false, skippedDimensionIds: [], intrinsicLevels: {} });
    doc.nextId = 501;
    const w = await h.createWritable();
    await w.write(JSON.stringify(doc));
    await w.close();
  });
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await expect(page.getByTestId('word-list')).toContainText('zomu', { timeout: 6000 });
  await context.close();
});

test('MCP help and Anki export work', async ({ page }) => {
  await newProject(page, 'Anki');
  await page.getByRole('button', { name: 'Grammar' }).click();
  await addPos(page, 'Noun', 'n');
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await page.getByRole('button', { name: 'New word' }).click();
  await page.getByLabel('Romanization *').fill('zomu');
  await page.getByLabel('Part of speech *').selectOption({ label: 'Noun' });
  await page.getByRole('button', { name: 'New word' }).nth(1).click();
  await page.getByRole('button', { name: 'Export to Anki' }).click();
  await page.getByLabel('Select all').check();
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export 1 to Anki' }).click();
  expect((await download).suggestedFilename()).toMatch(/\.apkg$/);
  await page.getByRole('button', { name: 'View', exact: true }).click();
  await page.getByRole('menuitem', { name: /AI Tools/ }).click();
  await expect(page.getByRole('dialog')).toContainText('conlang-workbench');
});

test('typing V, C and (C) in a pattern field makes class chips right away', async ({ page }) => {
  await newProject(page, 'Typed');
  await addPhoneme(page, 'k');
  await addPhoneme(page, 'a');
  await page.getByRole('link', { name: 'Sound Rules' }).click();

  await page.getByTestId('add-template').click();
  const field = page.getByLabel('Template: add sound');
  await field.pressSequentially('(C)V(C)');
  await expect(page.getByTestId('template-editor').locator('.seg-chip')).toContainText(['(C)', 'V', '(C)']);
  await expect(field).toHaveValue('');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('(C)V(C)', { exact: true })).toBeVisible();

  await page.getByTestId('add-rewrite').click();
  await page.getByLabel('Pattern: add sound').pressSequentially('k');
  await page.getByLabel('Replacement (phonetic)').fill('x');
  await page.getByLabel('Before: add sound').pressSequentially('V');
  await page.getByLabel('After: add sound').pressSequentially('V');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('k → x / V_V')).toBeVisible();

  await page.getByTestId('add-constraint').click();
  await page.locator('.dialog').getByText('Forbidden sequence', { exact: true }).click();
  await page.getByLabel('Forbidden pattern: add sound').pressSequentially('[stop]C');
  await expect(page.locator('.dialog .seg-chip')).toContainText(['[stop]', 'C']);
  await page.locator('.dialog').getByRole('button', { name: 'Cancel' }).click();
});

test('automatic derivations are generated, searchable and follow their rule', async ({ page }) => {
  await newProject(page, 'Auto');
  await page.getByRole('button', { name: 'Grammar' }).click();
  await addPos(page, 'Verb', 'v');
  await addPos(page, 'Noun', 'n');
  await page.getByRole('button', { name: 'Lexicon' }).click();
  await page.getByRole('link', { name: 'Derivations' }).click();
  await page.getByRole('button', { name: 'Add Rule' }).click();
  await page.getByLabel('Rule name').fill('Actor');
  await page.getByLabel('Input POS').selectOption({ label: 'Verb (v.)' });
  await page.getByLabel('Output POS').selectOption({ label: 'Noun (n.)' });
  await page.getByRole('button', { name: 'Automatic' }).click();
  await page.getByLabel('Affix').fill('er');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await expect(page.getByTestId('rule-Actor')).toContainText('Automatic');

  await page.getByRole('link', { name: 'Dictionary' }).click();
  await page.getByRole('button', { name: 'New word' }).click();
  await page.getByLabel('Romanization *').fill('bak');
  await page.getByLabel('Meaning').fill('to bake');
  await page.getByLabel('Part of speech *').selectOption({ label: 'Verb' });
  await page.getByRole('button', { name: 'New word' }).nth(1).click();

  // On the word's page, not in the main list.
  await expect(page.getByTestId('derived-Actor').getByTestId('derived-form')).toContainText('baker');
  await expect(page.getByTestId('word-count')).toHaveText('1 word');
  await page.getByRole('button', { name: 'Show automatic words' }).click();
  await expect(page.getByTestId('word-count')).toHaveText('2 words');
  await page.getByRole('button', { name: 'Show automatic words' }).click();
  await page.getByLabel('Search words').fill('baker');
  await expect(page.getByTestId('word-baker')).toContainText('auto');
  await page.getByLabel('Search words').fill('');

  // Selecting it opens a full page; a meaning is saved on top.
  await page.getByTestId('derived-Actor').getByTestId('derived-form').click();
  await expect(page.getByTestId('word-form')).toHaveText('baker');
  await expect(page.getByTestId('automatic-note')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Delete word' })).toHaveCount(0);
  await expect(page.getByTestId('word-detail')).toContainText('to bake (Actor)');
  await page.getByRole('button', { name: 'Edit word' }).click();
  await page.getByLabel('Meaning').fill('one who bakes bread');
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(page.getByTestId('word-detail')).toContainText('one who bakes bread');
  await expect(page.getByTestId('word-count')).toHaveText('1 word');

  // Changing the rule updates the word, and the meaning stays.
  await page.getByRole('link', { name: 'Derivations' }).click();
  await page.getByRole('button', { name: 'Edit rule' }).click();
  await page.getByLabel('Affix').fill('or');
  await page.locator('.dialog').getByRole('button', { name: 'Save' }).click();
  await page.getByRole('link', { name: 'Dictionary' }).click();
  await expect(page.getByTestId('word-form')).toHaveText('bakor');
  await expect(page.getByTestId('word-detail')).toContainText('one who bakes bread');

  // An irregular form stays on top too, without detaching.
  await page.getByRole('button', { name: 'Edit word' }).click();
  await page.getByLabel('Romanization *').fill('baxter');
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(page.getByTestId('word-form')).toHaveText('baxter');
  await expect(page.getByTestId('derived-via')).toContainText('Actor');
  await expect(page.getByTestId('word-count')).toHaveText('1 word');
  await page.getByRole('button', { name: 'Reset to rule output' }).click();
  await expect(page.getByTestId('word-form')).toHaveText('bakor');
  await expect(page.getByTestId('word-detail')).toContainText('to bake (Actor)');

  // The scratchpad reads it.
  await page.getByRole('button', { name: 'Scratchpad' }).click();
  await page.getByRole('button', { name: 'New Phrase' }).click();
  await page.getByLabel('Phrase', { exact: true }).fill('bakor');
  await expect(page.getByTestId('gloss')).toHaveText(['to bake (Actor)']);
});
