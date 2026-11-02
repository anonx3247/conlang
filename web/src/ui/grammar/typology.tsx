import * as cmd from '../../core/commands';
import type { ProjectDoc } from '../../core/types';
import { run, useDoc } from '../../storage/store';
import { Icon, Select } from '../common';

type Key = keyof ProjectDoc['settings']['typology'];

const SECTIONS: { key: Key; label: string; tip: string; options: [string, string][] }[] = [
  { key: 'alignment', label: 'Alignment', tip: 'Nominative-accusative: subjects of intransitive and transitive verbs share marking. Ergative-absolutive: intransitive subjects and direct objects share marking. Split: varies by tense, aspect, or animacy.', options: [['nom_acc', 'Nominative-Accusative'], ['erg_abs', 'Ergative-Absolutive'], ['split', 'Split']] },
  { key: 'wordOrder', label: 'Basic Word Order', tip: 'The default order of Subject (S), Verb (V), and Object (O) in declarative sentences.', options: [['SVO', 'SVO'], ['SOV', 'SOV'], ['VSO', 'VSO'], ['VOS', 'VOS'], ['OVS', 'OVS'], ['OSV', 'OSV'], ['free', 'Free / Topic-prominent']] },
  { key: 'modality', label: 'Modality Strategy', tip: 'Synthetic: modality expressed by inflectional morphology. Analytic: modality expressed by auxiliary verbs or particles. Mixed: both.', options: [['synthetic', 'Synthetic'], ['analytic', 'Analytic'], ['mixed', 'Mixed']] },
  { key: 'headDirection', label: 'Head Directionality', tip: 'Whether heads come before or after their dependents.', options: [['head_initial', 'Head-initial'], ['head_final', 'Head-final'], ['mixed', 'Mixed']] },
  { key: 'adposition', label: 'Adposition Type', tip: 'Where adpositions sit relative to their noun.', options: [['preposition', 'Preposition'], ['postposition', 'Postposition'], ['circumposition', 'Circumposition']] },
  { key: 'adjectivePlacement', label: 'Adjective Placement', tip: 'Where adjectives sit relative to the noun.', options: [['prenominal', 'Prenominal'], ['postnominal', 'Postnominal']] },
  { key: 'genitivePlacement', label: 'Genitive Placement', tip: 'Where possessors sit relative to the possessed noun.', options: [['prenominal', 'Prenominal'], ['postnominal', 'Postnominal']] },
];

export function TypologyPage() {
  const doc = useDoc();
  return (
    <div className="col pad-lg" style={{ maxWidth: 560, gap: 20 }}>
      <h1 className="h-large">Typology</h1>
      {SECTIONS.map((s) => (
        <div key={s.key} className="col" style={{ gap: 6 }}>
          <div className="row"><span className="bold">{s.label}</span><span title={s.tip}><Icon name="info_outline" size={15} className="faint" /></span></div>
          <Select ariaLabel={s.label} value={doc.settings.typology[s.key] ?? null} placeholder="" options={s.options.map(([value, label]) => ({ value, label }))} onChange={(v) => { if (v) run((d) => cmd.setTypology(d, s.key, v)); }} />
        </div>
      ))}
    </div>
  );
}
