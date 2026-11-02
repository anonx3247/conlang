import ipaSounds from '../../data/ipa_sounds.json';
import { hasIpaAudio, isPlaceableVowel, playIpa, vowelPosition, VowelTrapezoid } from '../ipa';

const MANNERS: [string, string][] = [['plosive', 'Plosive'], ['nasal', 'Nasal'], ['trill', 'Trill'], ['tap/flap', 'Tap/Flap'], ['fricative', 'Fricative'], ['lateral fricative', 'Lat. Fric.'], ['approximant', 'Approx.'], ['lateral approximant', 'Lat. Approx.'], ['affricate', 'Affricate']];
const PLACES: [string, string][] = [['bilabial', 'Bi'], ['labiodental', 'Ld'], ['dental', 'De'], ['alveolar', 'Al'], ['postalveolar', 'Pa'], ['retroflex', 'Rf'], ['palatal', 'Pl'], ['velar', 'Ve'], ['uvular', 'Uv'], ['pharyngeal', 'Ph'], ['glottal', 'Gl'], ['labial-velar', 'LV'], ['labial-palatal', 'LP']];

function Sym({ s }: { s?: { symbol: string; name: string } }) {
  if (!s) return <span style={{ display: 'inline-block', width: 9 }} />;
  const audible = hasIpaAudio(s.symbol);
  return (
    <button type="button" className={`ipa-sym ${audible ? '' : 'silent'}`} title={audible ? s.name : `${s.name} (no recording)`} onClick={() => playIpa(s.symbol)}>
      {s.symbol}
    </button>
  );
}

const Label = ({ children }: { children: string }) => <div className="tiny bold muted" style={{ padding: '12px 0 4px' }}>{children}</div>;

export function IpaChartPanel() {
  const width = 264;
  const height = 120;
  const vowelGroups = new Map<string, typeof ipaSounds.vowels>();
  for (const v of ipaSounds.vowels) {
    if (!isPlaceableVowel(v.height, v.backness)) continue;
    const k = `${v.height}|${v.backness}`;
    vowelGroups.set(k, [...(vowelGroups.get(k) ?? []), v]);
  }
  return (
    <div className="col fill" style={{ background: 'var(--surface-container)', gap: 0 }} data-testid="ipa-chart">
      <div className="tiny bold muted" style={{ padding: '12px 12px 4px', letterSpacing: 1.2 }}>IPA REFERENCE</div>
      <div className="grow scroll" style={{ padding: '0 12px 12px' }}>
        <Label>Pulmonic Consonants</Label>
        <div className="chart-grid" style={{ gridTemplateColumns: `58px repeat(${PLACES.length}, minmax(24px, 1fr))`, minWidth: 58 + PLACES.length * 24 }}>
          <span />
          {PLACES.map(([p, l]) => <span key={p} title={p} className="faint" style={{ textAlign: 'center' }}>{l}</span>)}
          {MANNERS.flatMap(([m, label]) => [
            <span key={m} className="muted ellipsis">{label}</span>,
            ...PLACES.map(([p]) => {
              const here = ipaSounds.pulmonic.filter((s) => s.manner === m && s.place === p);
              if (!here.length) return <span key={m + p} style={{ background: 'rgba(226,226,233,.04)', height: 18, display: 'block' }} />;
              return (
                <span key={m + p} className="row" style={{ justifyContent: 'center', gap: 0, overflow: 'hidden' }}>
                  <Sym s={here.find((s) => s.voiced === false)} />
                  <Sym s={here.find((s) => s.voiced === true)} />
                </span>
              );
            }),
          ])}
        </div>
        <Label>Vowels</Label>
        <div style={{ padding: '6px 10px 10px' }}>
          <VowelTrapezoid width={width} height={height}>
            {[...vowelGroups.entries()].map(([k, list]) => {
              const [h, b] = k.split('|');
              const pos = vowelPosition(h, b, width, height);
              return (
                <span key={k} className="row" style={{ position: 'absolute', left: pos.x, top: pos.y, transform: 'translate(-50%,-50%)', gap: 1 }}>
                  <Sym s={list.find((s) => !s.rounded)} />
                  <Sym s={list.find((s) => s.rounded)} />
                </span>
              );
            })}
          </VowelTrapezoid>
        </div>
        <Label>Non-Pulmonic</Label>
        {[['click', 'Clicks'], ['implosive', 'Implosives'], ['ejective', 'Ejectives']].map(([m, label]) => (
          <div key={m} className="row" style={{ gap: 6, padding: '2px 0' }}>
            <span className="tiny muted" style={{ width: 64 }}>{label}</span>
            <span className="row wrap" style={{ gap: 2 }}>{ipaSounds.nonPulmonic.filter((s) => s.manner === m).map((s) => <Sym key={s.symbol} s={s} />)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
