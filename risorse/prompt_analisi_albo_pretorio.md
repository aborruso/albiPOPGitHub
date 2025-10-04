# Prompt per Analisi e Creazione Feed RSS Albo Pretorio

## Contesto
Devi analizzare il sito web dell'albo pretorio di un comune italiano e creare uno script automatico per generare un feed RSS delle pubblicazioni. Segui questo approccio metodico basato sul progetto AlboPOP.

## Input richiesto dall'utente
Prima di iniziare, chiedi all'utente:

1. **URL del sito**: L'indirizzo web dell'albo pretorio del comune
2. **Nome del comune**: Nome completo del comune
3. **Codice ISTAT**: Codice identificativo del comune (formato: c_XXXX)
4. **Provincia e regione**: Per i metadati del feed
5. **Coordinate geografiche**: Latitudine e longitudine (opzionale, puoi cercarle)

## Fase 1: Analisi della struttura HTML

### Ispezione iniziale
1. **Analizza la pagina principale** dell'albo pretorio
2. **Identifica la struttura HTML** delle pubblicazioni:
   - Cerca tabelle (`<table>`, `<tbody>`, `<tr>`)
   - Identifica i selettori CSS per: titolo, link, data pubblicazione
   - Verifica se esiste paginazione

### Strumenti per l'analisi
```bash
# Scarica la pagina per analisi
curl -kL "URL_ALBO" > analisi.html

# Esplora diverse strutture possibili
scrape -be '//table' < analisi.html | head -50          # Tabelle HTML
scrape -be '//tbody/tr' < analisi.html | head -20       # Righe in tbody
scrape -be '//tr' < analisi.html | head -20             # Tutte le righe
scrape -be '//div[contains(@class,"item")]' < analisi.html | head -20  # Div con classe item
scrape -be '//ul/li' < analisi.html | head -20          # Liste
scrape -be '//*[contains(@class,"pubblicazione")]' < analisi.html | head -20  # Qualsiasi elemento con classe
```

### Patterns comuni da cercare
1. **Strutture tabellari**:
   - `//table//tr` - Righe di tabella
   - `//tbody/tr` - Righe nel body della tabella
   - `//thead/tr` + `//tbody/tr` - Tabelle con header

2. **Strutture a div/card**:
   - `//div[contains(@class,"item")]` - Div con classe "item"
   - `//div[contains(@class,"pubblicazione")]` - Div pubblicazioni
   - `//div[contains(@class,"document")]` - Div documenti

3. **Strutture a lista**:
   - `//ul/li` - Liste semplici
   - `//ol/li` - Liste ordinate

### Domande da risolvere per ogni elemento trovato
- **Container principale**: Qual è l'xpath che cattura tutti gli elementi?
- **Titolo**: Dove si trova? (link, span, div, text node)
- **URL**: Attributo href di quale elemento?
- **Data**: In che formato? (dd/mm/yyyy, yyyy-mm-dd, testo italiano)
- **Altri dati**: Numero, tipo documento, scadenza (se presenti)

### Esempi di estrazione per diverse strutture

#### Per tabelle:
```bash
# Identifica le colonne
scrape -be '//thead/tr/th' < analisi.html  # Vedi intestazioni
scrape -be '//tbody/tr[1]/td' < analisi.html  # Prima riga di dati

# Test generico per tabelle
scrape -be '//tbody/tr' < analisi.html | \
xq -c '.html.body.tr[] | {
  titolo: (.td[0] // .td[1] // .td[2]),
  url: (.td[0].a."@href" // .td[1].a."@href" // .td[2].a."@href"),
  data: (.td[-1] // .td[-2] // .td[-3])
}'
```

#### Per div/card:
```bash
# Test per strutture div
scrape -be '//div[contains(@class,"item") or contains(@class,"document")]' < analisi.html | \
xq -c '.html.body.div[] | {
  titolo: (.h3 // .h4 // .a // .span // ."#text"),
  url: (.a."@href" // .//a."@href"),
  data: (.//span[contains(@class,"date")] // .//div[contains(@class,"date")])
}'
```

#### Per liste:
```bash
# Test per liste
scrape -be '//ul/li | //ol/li' < analisi.html | \
xq -c '.html.body.li[] | {
  titolo: (.a // .span // ."#text"),
  url: (.a."@href" // .//a."@href"),
  data: (.//span // .//div)
}'
```

## Fase 2: Test sistematico di estrazione

### Approccio step-by-step
1. **Identifica il pattern**: Usa i comandi sopra per trovare la struttura
2. **Raffina i selettori**: Aggiusta xpath per catturare esattamente titolo, url, data
3. **Testa su più elementi**: Verifica che funzioni su almeno 5-10 elementi
4. **Gestisci variazioni**: Alcuni elementi potrebbero mancare certi campi

### Verifica paginazione
Se esiste paginazione, testa:
```bash
# Esempio: testare pagina 1, 2, 3
curl -kL "URL_BASE?pag=0" > page0.html
curl -kL "URL_BASE?pag=1" > page1.html
curl -kL "URL_BASE?pag=2" > page2.html
```

## Fase 3: Creazione script bash

### Template di base
Crea uno script seguendo il pattern di `c_l109.sh`:

```bash
#!/bin/bash

### Configurazione comune ###
folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
git pull

# Anagrafica albo
titolo="AlboPOP del comune di [NOME_COMUNE]"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="[NOME_COMUNE]"
iPA="[CODICE_ISTAT]"
municipality="[NOME_COMUNE]"
province="[PROVINCIA]"
region="[REGIONE]"
latitude="[LAT]"
longitude="[LON]"
# Altri metadati...

### Download multi-pagina ###
for page in 0 1 2; do
  URLPaginata="[URL_BASE_CON_PARAMETRI]&pag=$page"
  # Logica di download e estrazione
done

### Elaborazione dati ###
# Combinazione pagine, rimozione duplicati
# Conversione formati, gestione caratteri speciali
# Generazione feed RSS
```

### Elementi chiave da personalizzare

1. **URL di base**: Adatta l'URL con i parametri corretti per la paginazione
2. **Comando di estrazione**: Sostituisci la logica specifica del comune:
   ```bash
   # TEMPLATE GENERICO - personalizza in base alla struttura trovata

   # Per tabelle:
   scrape -be '//tbody/tr' | \
   xq -c '.html.body.tr[] | select(.td | length > 0) | {
     titolo: .td[INDICE_TITOLO].SELETTORE_TITOLO,
     url: .td[INDICE_URL].a."@href",
     data: .td[INDICE_DATA].SELETTORE_DATA
   }'

   # Per div/card:
   scrape -be '//div[contains(@class,"CLASSE")]' | \
   xq -c '.html.body.div[] | {
     titolo: .SELETTORE_TITOLO,
     url: .a."@href" // .//a."@href",
     data: .SELETTORE_DATA
   }'

   # Per liste:
   scrape -be '//ul/li | //ol/li' | \
   xq -c '.html.body.li[] | {
     titolo: .a // .span // ."#text",
     url: .a."@href" // .//a."@href",
     data: .SELETTORE_DATA
   }'
   ```

3. **Formato data**: Adatta il parsing della data al formato del comune:
   ```bash
   # Esempi comuni di conversione data:

   # Da "dd/mm/yyyy" a "yyyy-mm-dd"
   put '$data=strftime(strptime($data,"%d/%m/%Y"),"%Y-%m-%d")'

   # Da "dd-mm-yyyy" a "yyyy-mm-dd"
   put '$data=strftime(strptime($data,"%d-%m-%Y"),"%Y-%m-%d")'

   # Da "dd/mm/yyyy HH:MM" a "yyyy-mm-dd"
   put '$data=strftime(strptime($data,"%d/%m/%Y %H:%M"),"%Y-%m-%d")'

   # Da formato italiano "1 gennaio 2024" (richiede logica aggiuntiva)
   # put '$data=gsub($data,"gennaio","01")' then put '$data=gsub($data,"febbraio","02")' ...
   ```

4. **Paginazione**: Configura i parametri per scaricare più pagine
   ```bash
   # Esempi comuni di parametri paginazione:

   # Parametro 'pag' o 'page'
   for page in 0 1 2; do
     URLPaginata="${URL}?pag=$page"
   done

   # Parametro 'start' con offset
   for page in 0 20 40; do  # 20 elementi per pagina
     URLPaginata="${URL}?start=$page"
   done

   # Parametro 'p' con numerazione da 1
   for page in 1 2 3; do
     URLPaginata="${URL}?p=$page"
   done
   ```

5. **Metadati**: Imposta tutti i dati anagrafici del comune
6. **URL completi**: Gestisci URL relativi/assoluti:
   ```bash
   # Se gli URL sono relativi, aggiungi il dominio base
   then put 'if (test($url,"^/")) {$url="https://DOMINIO_BASE".$url} else {$url=$url}'
   ```

## Fase 4: Gestione caratteri speciali

### Caratteri comuni da gestire
```bash
# In mlr, aggiungi le sostituzioni necessarie:
put '$titolo=gsub($titolo,">","&gt;")' \
then put '$titolo=gsub($titolo,"&","&amp;")' \
then put '$titolo=gsub($titolo,"'\''","&apos;")' \
then put '$titolo=gsub($titolo,"\"","&quot;")' \
then put '$titolo=gsub($titolo,"°","&#176;")' \
# Aggiungi altri caratteri problematici che trovi
```

### Test di validazione
```bash
# Verifica il feed generato
xmlstarlet val docs/[CODICE]/feed.xml
# Test online: https://validator.w3.org/feed/
```

## Fase 5: Workflow GitHub Actions

### Crea file workflow
File: `.github/workflows/[CODICE].yml`

```yaml
name: crea feed RSS [CODICE]
on:
  schedule:
    - cron: "0 9,15 * * *"  # 9:00 e 15:00 UTC
  workflow_dispatch:
jobs:
  scheduled:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: crea cartella utente bin, installa dipendenze
        run: |
          mkdir -p $HOME/.local/bin
          cp bin/mlr_6 $HOME/.local/bin/mlr
          sudo apt-get install -y xmlstarlet
          # Installa altre dipendenze necessarie
      - name: scarica i dati e crea feed
        run: |
          cd [CODICE]
          bash ./[CODICE].sh
      - name: Committa e pusha se ci sono variazioni nei dati
        run: |
          git config --global user.email "action@github.com"
          git config --global user.name "GitHub Action"
          git add -A
          git commit -m "Data updated" || exit 0
          git push
```

## Checklist finale

- [ ] **Script bash funzionante**: Esegue senza errori
- [ ] **Multi-pagina**: Scarica almeno 3 pagine se disponibili
- [ ] **Rimozione duplicati**: Usa `unique_by(.url)`
- [ ] **Caratteri speciali**: Gestisce tutti i caratteri problematici
- [ ] **Feed valido**: Passa la validazione W3C
- [ ] **Workflow GitHub**: Si esegue automaticamente
- [ ] **Metadati completi**: Tutti i dati anagrafici corretti
- [ ] **Error handling**: Gestisce errori di rete e parsing
- [ ] **Logging**: Output informativi durante l'esecuzione
- [ ] **Pulizia**: Rimuove file temporanei

## Note aggiuntive

### Problemi comuni e soluzioni
1. **Timeout di rete**: Aggiungi retry logic
2. **Caratteri Unicode**: Verifica encoding UTF-8
3. **Struttura HTML complessa**: Usa più step di parsing
4. **Rate limiting**: Aggiungi pause tra richieste
5. **JavaScript required**: Valuta uso di browser headless

### Tools utili
- **scrape-cli**: Estrazione HTML con XPath
- **mlr (Miller)**: Manipolazione dati JSON/CSV
- **jq**: Processing JSON avanzato
- **xmlstarlet**: Manipolazione XML/RSS
- **xq**: Conversione HTML->JSON

### Risorse di riferimento
- Esempio completo: `c_l109/c_l109.sh`
- Template feed: `risorse/feedTemplate.xml`
- Workflow di esempio: `.github/workflows/c_l109.yml`
- Validatore RSS: https://validator.w3.org/feed/

## Prompt finale per l'IA

Quando usi questo prompt con un'IA, fornisci sempre:
1. L'URL dell'albo pretorio da analizzare
2. I dati anagrafici del comune
3. Esempi di HTML della pagina (almeno 50 righe)
4. Qualsiasi caratteristica speciale del sito (JavaScript, autenticazione, ecc.)

L'IA dovrebbe seguire tutte le fasi in sequenza e produrre uno script completo e funzionante.
