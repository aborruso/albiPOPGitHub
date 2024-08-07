const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({
    defaultViewport: { width: 1920, height: 1080 }
  });
  const page = await browser.newPage();
  // apri pagina
  await page.goto('https://cloud.urbi.it/urbi/progs/urp/ur1ME001.sto?DB_NAME=n1233954', { waitUntil: 'domcontentloaded' });

  // definisci pulsante da cercare
  const linkHandlers = await page.$x("//a[contains(text(), 'Visualizza')]");

  if (linkHandlers.length > 0) {
    //fai click sul pulsante
    await linkHandlers[0].click();
    //aspetta che si carica la pagina
    await page.waitForNavigation({ waitUntil: 'load' });
  } else {
    throw new Error("Link not found");
  }
  // recupera il contenuto HTML della pagina
  var HTML = await page.content()
  const fs = require('fs');
  // salva il contenuto HTML nella cartella corrente
  var ws = fs.createWriteStream(
    './tmp.html'
  );
  ws.write(HTML);
  ws.end();
  browser.close();
})();
