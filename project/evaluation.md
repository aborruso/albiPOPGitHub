# Valutazione AlbiPOPGitHub

Data: 2025-12-24

## Sintesi

**Stato generale**: Produzione operativa, pronto per raffinamento
**Scala**: 17 comuni + 1 area regionale (CDTDR), 18 workflow GitHub Actions
**Architettura**: Solida, pattern chiari, implementazione OpenSpec eccellente

---

## Punti di forza

### Architettura e organizzazione

- Pattern scraping ben definiti (bash pipeline, rsspls, Python/Playwright)
- Struttura cartelle standardizzata (`c_XXXXX` con codice IPA)
- Separazione completa: ogni comune è autonomo
- Template RSS condiviso (`risorse/feedTemplate.xml`)
- Framework OpenSpec implementato per sviluppo spec-driven

### Automazione

- GitHub Actions funzionale per 18 comuni
- Trigger multipli: manuale, cron, repository_dispatch
- Git integrato: ogni script fa `git pull` prima di eseguire
- Pubblicazione automatica via GitHub Pages

### Documentazione

- `CLAUDE.md` e `openspec/project.md` completi
- Prompt AI disponibili per nuovi comuni (`risorse/prompt_*.md`)
- Spec funzionalità ben definite in `specs/municipal-feed/`

---

## Criticità da risolvere

### Alta priorità

1. **Debug attivo in produzione** - 16 script su 18 hanno `set -x` (verbose trace)
   - Impatto: log eccessivi, performance ridotta
   - Fix: rimuovere `-x` dagli script produzione

2. **Gestione errori mancante** - 5 script senza `set -e`:
   - `c_a026/c_a026.sh`
   - `c_c067/c_c067.sh`
   - `c_e036/c_e036.sh`
   - `c_l736/c_l736.sh`
   - `c_a638_old.sh` (legacy)
   - Rischio: fallimenti silenziosi

3. **Script incompleti** - Pattern D problematico:
   - `c_a638`, `c_a965`, `c_i725` minimali (10-17 righe)
   - `c_b645` non genera output in `docs/c_b645/`
   - Da verificare: funzionamento effettivo

4. **Metadati incompleti** - `c_a026`: `webMaster="undefined"`

### Media priorità

1. **Duplicazione workflow** - Setup dipendenze ripetuto 18 volte
   - Manutenzione gravosa
   - Rischio: drift versioni tool

2. **Versioni Miller multiple** - `bin/` contiene mlr, mlr_6, mlrgo
   - Confusione su quale usare
   - Consolidare su versione unica

3. **README per-comune mancanti** - Solo 3 comuni documentati (c_d003, c_l109, c_a026)

4. **LOG.md minimale** - Una sola entry datata 2025-07-12

### Bassa priorità

1. **Duplicazione codice** - Pattern A replica 80% boilerplate
   - Estrarre funzioni bash condivise

2. **Test assenti** - Nessun test automatico
   - Validazione manuale

3. **Metadati hardcoded** - Coordinate/titoli non centralizzati

---

## Pattern scraping

### Pattern A - Bash pipeline completo (8 comuni)

Esempio: `c_d003`, `c_e047`, `c_f284`

Flusso: curl → Puppeteer/scrape → xq → mlr → xmlstarlet
Dimensione: 100-170 righe
Gestisce: paginazione, cookie, parsing date complesso

**Pro**: Flessibilità massima
**Contro**: Alta duplicazione, fragilità pipeline

### Pattern B - rsspls (4 comuni)

Esempio: `c_a546`, `c_a965`, `c_a638`, `c_i725`

File: `feeds.toml` con selettori CSS
Dimensione: 10-18 righe wrapper
Gestisce: estrazione diretta via configurazione

**Pro**: Semplicità, eleganza
**Contro**: Meno flessibile, validazione HTTP assente

### Pattern C - Python/Playwright (1 comune)

Esempio: `c_b645`

Tecnologia: Python async + Playwright
Dimensione: 34 righe wrapper + script Python

**Pro**: Approccio moderno
**Contro**: Unico nel codebase, output mancante

### Pattern D - Stub/incompleto (4 comuni)

Esempio: `c_a638`, `c_a965`, `c_i725`, `c_a026`

Dimensione: 10-17 righe
Stato: Minimali, funzionamento dubbio

---

## Statistiche codebase

- **Totale righe bash**: ~1,591 (script comuni)
- **Binari in `bin/`**: 95MB totale (mlr, scrape, rsspls)
- **Workflow attivi**: 18
- **Feed pubblicati**: 16/18 (c_b645 e c_i725 problematici)
- **Commit giornalieri**: 15-20 automatici + modifiche manuali bisettimanali

---

## Rischi identificati

### Integrità dati

- Nessuna validazione contenuto feed generato
- Fallimenti silenziosi possibili in Pattern B
- Vulnerabilità XML injection in Pattern C (concatenazione stringhe Python)

### Operatività

- Binari solo x86-64 (no ARM)
- Rate limiting GitHub Actions non gestito (18 workflow paralleli)
- Dipendenze fragili (mlr, xmlstartar, yq in PATH)

### Scalabilità

- Crescita lineare comuni insostenibile con approccio manuale
- Nessun templating automatico
- Revisione manuale ancora fattibile (17 comuni)

---

## Raccomandazioni

### Immediate

1. Rimuovere `set -x` da script produzione
2. Aggiungere `set -e` ai 5 script mancanti
3. Testare Pattern D, correggere c_b645/c_i725
4. Completare metadati c_a026

### Breve termine

1. Centralizzare setup workflow (reusable workflow o action condivisa)
2. Consolidare versioni Miller
3. Creare README per ogni comune
4. Aggiornare LOG.md regolarmente

### Lungo termine

1. Estrarre libreria funzioni bash comuni
2. Implementare test integrazione feed
3. Aggiungere validazione qualità dati
4. Sistema templating per nuovi comuni

---

## Valutazione complessiva

| Aspetto | Voto | Note |
|---------|------|------|
| **Documentazione** | 8/10 | Eccellente CLAUDE.md e openspec, mancano README per-comune |
| **Qualità codice** | 6/10 | Solida base, 5 script senza error handling |
| **Architettura** | 8/10 | Pattern chiari, alta duplicazione |
| **Automazione** | 8/10 | Workflow funzionali, setup ripetuto |
| **Test** | 2/10 | Solo validazione manuale |
| **Scalabilità** | 6/10 | OK per 17 comuni, approccio manuale limita crescita |
| **Conformità spec** | 9/10 | Framework OpenSpec ben implementato |

**Voto complessivo: 7/10**

Il progetto è **solido e funzionale**, con eccellente documentazione architetturale e framework OpenSpec. Le criticità sono circoscritte e risolvibili: rimozione debug, gestione errori, consolidamento tool. Opportunità principale: ridurre duplicazione logica script per facilitare manutenzione futura.
