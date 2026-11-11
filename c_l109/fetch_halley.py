#!/usr/bin/env python3
"""Legge il nuovo Halley di Terlizzi; scrape CLI estrae i dati dall'HTML."""
from datetime import datetime, timezone
from email.utils import format_datetime
from html import escape
from html.parser import HTMLParser
import http.cookiejar
import json
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.parse import urlencode, urljoin, urlsplit
from urllib.request import build_opener, HTTPCookieProcessor, Request, urlopen
import xml.etree.ElementTree as ET

BASE = 'https://www.comune.terlizzi.ba.it'
ENTRY = BASE + '/EG0/EGHOMEPAGE.HBL'
LISTING = ENTRY + '?ss=1&F=MC09&en=e1380&freeze=1&P='
GUID_PREFIX = 'urn:albopop:c_l109:'


def scrape(markup, *args):
    result = subprocess.run(['scrape', *args], input=markup, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def parse_cards(markup):
    fields = [
        ('position', './/a[starts-with(@onclick,"MC02(")]/@onclick'),
        ('titolo', './/h5'),
        ('number', './/div[contains(@class,"category-top")]/span'),
        ('period', './/span[strong[contains(.,"Pubblicazione dal")]]'),
        ('sender', './/span[strong[normalize-space(.)="Mittente:"]]'),
        ('kind', './/span[strong[normalize-space(.)="Tipo:"]]'),
    ]
    args = ['--row', '//div[contains(concat(" ",normalize-space(@class)," ")," card ")][.//a[starts-with(@onclick,"MC02(")]]']
    for name, expression in fields:
        args += ['--field', f'{name}={expression}']
    result = []
    for item in json.loads(scrape(markup, *args)):
        dates = re.findall(r'\d{2}-\d{2}-\d{4}', item['period'] or '')
        if len(dates) != 2 or not item['titolo']:
            raise ValueError(f'Pubblicazione senza titolo o date valide: {item["number"]!r}, {item["period"]!r}')
        start = datetime.strptime(dates[0], '%d-%m-%Y').replace(tzinfo=timezone.utc)
        number = re.search(r'\d+', item['number'] or '')
        position = re.fullmatch(r"MC02\(['\"]?(\d+)['\"]?\)", item['position'] or '')
        if not number or not position:
            raise ValueError('Identificativo della pubblicazione non valido')
        item.update(id=f'{start.year}-{number[0]}', number=number[0], position=position[1],
                    pubDate=format_datetime(start), start=dates[0], end=dates[1])
        result.append(item)
    return result


class Halley:
    def __init__(self):
        self.session = build_opener(HTTPCookieProcessor(http.cookiejar.CookieJar()))
        form = urlencode({'ss': '1', 'F': 'MC09', 'en': 'e1380', 'freeze': '1', 'P': ''})
        markup = self.request(ENTRY, form.encode(), 'application/x-www-form-urlencoded')
        target = scrape(markup, '-a', 'content', '-e', 'meta[name="jb"]')
        self.endpoint = urljoin(BASE + '/', target)
        if not target or urlsplit(self.endpoint).netloc != urlsplit(BASE).netloc:
            raise ValueError('Endpoint di sessione Halley non trovato')

    def request(self, url, data, content_type):
        request = Request(url, data=data, headers={'Content-Type': content_type, 'User-Agent': 'Mozilla/5.0'})
        for attempt in range(3):
            try:
                with self.session.open(request, timeout=30) as response:
                    return response.read().decode(response.headers.get_content_charset() or 'utf-8', errors='replace')
            except (URLError, TimeoutError):
                if attempt == 2:
                    raise
                time.sleep(2)

    def post(self, function, **params):
        data = ('&' + urlencode({'F': function, **params, 'en': 'e1380'})).encode()
        return self.request(self.endpoint, data, 'text/plain;charset=UTF-8; boundary=AZazAZ')


def valid_document(url):
    parsed = urlsplit(url)
    return (parsed.scheme == 'https' and parsed.netloc == urlsplit(BASE).netloc
            and parsed.path.startswith('/halley/') and '/ht/e1380/' in parsed.path)


def verify_document(url, head=False):
    if not valid_document(url):
        raise ValueError('Link documento non appartenente alla fonte ufficiale')
    # Il firewall rifiuta Range (403): GET normale, oppure HEAD per la cache.
    request = Request(url, headers={'User-Agent': 'Mozilla/5.0'}, method='HEAD' if head else 'GET')
    with urlopen(request, timeout=30) as response:
        content_type = response.headers.get('Content-Type', '').lower()
        sample = b'' if head else response.read(1024)
        path = urlsplit(url).path.lower()
        html_document = path.endswith(('.html', '.htm'))
        if (('text/html' in content_type and not html_document) or (head and not content_type)
                or (not head and (not sample
                    or (path.endswith('.pdf') and not sample.startswith(b'%PDF-'))
                    or any(error in sample.lower() for error in (b'403 forbidden', b'404 not found', b'request denied'))))):
            raise ValueError('Il link restituisce una pagina di errore, non il documento')


class CachedDocuments(HTMLParser):
    def __init__(self):
        super().__init__()
        self.documents = []
        self.current = None
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'a' and attrs.get('data-documento') == '1' and valid_document(attrs.get('href', '')):
            self.current = {'url': attrs['href'], 'name': ''}
    def handle_data(self, data):
        if self.current is not None:
            self.current['name'] += data
    def handle_endtag(self, tag):
        if tag == 'a' and self.current is not None:
            self.documents.append(self.current)
            self.current = None


def read_cache(path):
    if not path.exists():
        return {}
    cache = {}
    for item in ET.parse(path).findall('./channel/item'):
        guid = item.findtext('guid', '')
        if guid.startswith(GUID_PREFIX):
            parser = CachedDocuments()
            parser.feed(item.findtext('description', ''))
            if parser.documents:
                cache[guid.removeprefix(GUID_PREFIX)] = parser.documents
    return cache


def collect(client, cache, limit=30):
    items = []
    seen = set()
    recovered = 0
    page = 1
    while len(items) < limit:
        markup = client.post('MC01') if page == 1 else client.post('PMC02', **{'1': str(page)})
        cards = parse_cards(markup)
        if not cards:
            raise ValueError(f'Pagina {page} senza atti: non aggiorno il feed')
        total_pages = int(scrape(markup, '-t', '-e', '#totalePagine')) if page == 1 else total_pages
        for item in cards:
            if item['id'] in seen:
                raise ValueError(f'Pubblicazione ripetuta nella paginazione: {item["id"]}')
            seen.add(item['id'])
            documents = cache.get(item['id'], [])
            if documents:
                try:
                    for document in documents:
                        verify_document(document['url'], head=True)
                except (ValueError, OSError):
                    # I file Halley possono scadere: richiedere nuovi link ufficiali.
                    documents = []
            if not documents:
                detail = client.post('MC02', NUMRIGA=item['position'])
                heading = scrape(detail, '-t', '-e', '//h1[contains(.,"Pubblicazione n.")]')
                if not re.search(rf'\b{item["number"]}/{item["id"].split("-")[0]}\b', heading):
                    raise ValueError(f'Dettaglio non corrispondente alla pubblicazione {item["id"]}')
                doc_rows = json.loads(scrape(detail, '--row', '//a[starts-with(@onclick,"MC98(") or starts-with(@onclick,"MC99(") or starts-with(@onclick,"MC96(") or starts-with(@onclick,"MC97(")]',
                                             '--field', 'action=@onclick', '--field', 'name=.//text()[normalize-space()]'))
                documents = []
                for doc in doc_rows:
                    action = re.fullmatch(r"(MC9[6789])\(['\"]?(\d+)['\"]?\)", doc['action'])
                    if not action:
                        raise ValueError('Comando allegato non valido')
                    data = json.loads(client.post(action[1], NUMRIG=action[2]))
                    url = data.get('PATH', '')
                    if data.get('K') != '000' or not valid_document(url):
                        raise ValueError(f'Documento non disponibile per {item["id"]}')
                    if not any(d['url'] == url for d in documents):
                        verify_document(url)
                        documents.append({'name': doc['name'], 'url': url})
                if not documents:
                    raise ValueError(f'Pubblicazione {item["id"]} senza documenti accessibili')
                recovered += 1
            item['link'] = documents[0]['url']
            item['guid'] = GUID_PREFIX + item['id']
            item['description'] = (
                f'<p>Pubblicazione n. {item["number"]}/{item["id"].split("-")[0]} — '
                f'dal {item["start"]} al {item["end"]}</p>'
                f'<p>{escape(item["sender"] or "")} — {escape(item["kind"] or "")}</p><ul>'
                + ''.join(f'<li><a data-documento="1" href="{escape(d["url"], quote=True)}">{escape(d["name"])}</a></li>' for d in documents)
                + f'</ul><p><a href="{escape(LISTING, quote=True)}">Albo pretorio del Comune di Terlizzi</a></p>')
            items.append(item)
            if len(items) == limit:
                break
        if page >= total_pages or len(items) == limit:
            break
        # Come il browser: uscire dalla scheda prima di cambiare pagina.
        client.post('MC08')
        page += 1
    items.sort(key=lambda i: (datetime.strptime(i['start'], '%d-%m-%Y'), int(i['number'])), reverse=True)
    print(f'Atti: {len(items)}; dettagli recuperati: {recovered}; pagine elenco: {page}', file=sys.stderr)
    return items


def main():
    cache = read_cache(Path(sys.argv[1]))
    result = collect(Halley(), cache)
    json.dump(result, sys.stdout, ensure_ascii=False)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, ET.ParseError, subprocess.CalledProcessError) as error:
        print(f'Errore Terlizzi: {error}', file=sys.stderr)
        sys.exit(1)
