# Albo POP Cori

L'albo pretorio del Comune di Cori non è raggiungibile da server residenti in USA, quindi non è possibile farlo "girare" tramite github actions.<br>
Per questa ragione è stato spostato su un server "altro".

# Requisiti

È basato su uno script `sh` che chiama degli script node-js che attivano la navigazione *headless* di chromiun. Lo script `sh` inoltre fa uso di alcune utility.<br>
Riassumendo:

- mlr https://github.com/johnkerl/miller
- xmlstarlet http://xmlstar.sourceforge.net/
- jq https://github.com/stedolan/jq
- scrape https://github.com/aborruso/scrape-cli
- puppeteer
- chromium-browser

## Installazione/configurazione server

Il server su cui gira è basato su Ubuntu 20 e sono state fatte le seguenti installazioni:

```
sudo apt install nodejs npm
sudo npm install -g puppeteer --unsafe-perm=true -allow-root && sudo apt install chromium-browser -y
sudo apt-get install xmlstarlet
sudo apt-get install miller
# nella cartella di progetto
npm i puppeteer
sudo apt-get install -yq --no-install-recommends libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 libnss3
sudo apt-get install -y libgbm-dev
sudo apt install -y python3-pip
sudo apt install jq
pip3 install --upgrade --user yq
```

È stato modificato il `$PATH` per avere la cartella `bin` di python mappata, per avere disponibili gli eseguibili `yq` e `xq`. Per farlo è stato aggiunto `/home/admin-albpret-vm/.local/bin` al file `/etc/environment`.

L'eseguibile di `scrape` è stato inserito in `/home/admin-albpret-vm/bin`

# Lo script

Lo script principale è `/home/admin-albpret-vm/progetti/alboCori/c_d003.sh`. Esegue questi compiti:

- verifica se il portale è raggiungibile, altrimenti esce;
- se è raggiungibile esegue lo script node-js `/home/admin-albpret-vm/progetti/alboCori/c_d003.js`, che scarica la pagina con l'elenco degli atti in `/home/admin-albpret-vm/progetti/alboCori/tmp.html`
- estrae dal `tmp.html` la lista degli atti, li normalizza, crea gli elementi chiave (titolo, URL, data) e crea il feed RSS;
- copia il feed in `/home/admin-albpret-vm/progetti/docs/c_d003`.

Lo script può essere lanciato tramite `crontab` ogni giorno a una certa ora, almeno una volta al giorno.

Il file del feed `/home/admin-albpret-vm/progetti/docs/c_d003/feed.xml` va reso pubblico a un indirizzo `HTTP`. L'URL pubblico del feed, potrà essere usato per automatizzare la pubblicazione su IFTTT e altri spazi.
