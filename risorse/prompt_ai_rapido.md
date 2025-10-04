# Prompt Rapido per IA - Analisi Albo Pretorio

## Istruzioni per l'IA

Sei un esperto di web scraping e automazione. Devi analizzare un sito web di albo pretorio comunale italiano e creare uno script bash per generare automaticamente feed RSS delle pubblicazioni.

### Input che fornirò:
- URL dell'albo pretorio
- Nome del comune e dati anagrafici
- Esempi di HTML della pagina

### Il tuo compito:

1. **ANALISI STRUTTURA HTML**
   - Identifica i selettori XPath per estrarre: titolo, URL, data pubblicazione
   - Testa diverse strutture: tabelle (//tbody/tr), div (//div[contains(@class,"item")]), liste (//ul/li)
   - Usa scrape-cli per esplorare: `scrape -be '//table' | head -20`
   - Verifica se esiste paginazione e come funziona (parametri: pag, page, start, p)
   - Trova eventuali caratteri speciali problematici

2. **CREA SCRIPT BASH COMPLETO**
   - Segui il pattern del file `c_l109.sh` come riferimento architetturale
   - Implementa download multi-pagina (almeno 3 pagine se disponibili)
   - Usa `scrape -be` + `xq` per estrazione dati con xpath appropriati
   - Adatta i selettori alla struttura HTML specifica del sito:
     * Per tabelle: `.td[N].SELETTORE`
     * Per div/card: `.CLASSE_CSS.SELETTORE`
     * Per liste: `.li.SELETTORE`
   - Usa `mlr` per processamento dati e `xmlstarlet` per feed RSS
   - Gestisci formati data diversi: dd/mm/yyyy, dd-mm-yyyy, formato italiano
   - Gestisci URL relativi aggiungendo dominio base se necessario
   - Includi rimozione duplicati con `jq unique_by(.url)`

3. **CREA WORKFLOW GITHUB ACTIONS**
   - File `.github/workflows/[codice].yml`
   - Schedulazione: 9:00 e 15:00 UTC daily
   - Installa dipendenze: mlr_6, xmlstarlet, scrape-cli, xq

### Requisiti obbligatori:
- Script deve scaricare 3 pagine se disponibili
- Feed RSS deve essere valido W3C
- Gestire tutti i caratteri Unicode problematici
- Include error handling per problemi di rete
- Usa `git pull` all'inizio per evitare conflitti
- Pulisci file temporanei alla fine

### Output atteso:
1. Script bash completo e commentato
2. File workflow GitHub Actions
3. Lista di caratteri speciali trovati e come gestirli
4. Istruzioni per test e validazione

### Esempio di riferimento:
Studia il file `c_l109.sh` nel progetto AlboPOP per capire la struttura e il pattern da seguire.

**IMPORTANTE**: Lo script deve essere robusto, gestire errori di rete, e produrre sempre un feed RSS valido anche con dati parziali.
