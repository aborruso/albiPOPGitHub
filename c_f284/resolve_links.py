#!/usr/bin/env python3
"""Risolve e verifica i permalink del portale ASP.NET di Molfetta."""
import http.cookiejar
from html.parser import HTMLParser
import json
from pathlib import Path
import sys
import time
from urllib.error import URLError
from urllib.parse import parse_qs, urlencode, urljoin, urlsplit
from urllib.request import build_opener, HTTPCookieProcessor, Request
import xml.etree.ElementTree as ET

BASE = 'https://servizionline.comune.molfetta.ba.it/cmsmolfetta/portale/albopretorio/albopretorioconsultazione.aspx'
LISTING = BASE + '?P=400'


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.fields = {}
        self.target = None
        self.share = None
        self.document_ids = set()
        self.text = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'input':
            if attrs.get('type', '').lower() == 'hidden' and attrs.get('name'):
                self.fields[attrs['name']] = attrs.get('value', '')
            if '_hidden_row_' in attrs.get('id', ''):
                self.target = attrs['id'].split('_hidden_row_')[0]
            if attrs.get('id', '').endswith('_txtUrlShare'):
                self.share = attrs.get('value')
        if tag == 'a':
            url = urlsplit(urljoin(BASE, attrs.get('href', '')))
            if url.path.endswith('/getfile.aspx'):
                self.document_ids.update(parse_qs(url.query).get('PARAM', []))

    def handle_data(self, data):
        self.text.append(data)


def valid_link(url):
    parsed = urlsplit(url)
    base = urlsplit(BASE)
    return (parsed.scheme == base.scheme and parsed.netloc == base.netloc
            and parsed.path == base.path and not parsed.fragment
            and bool(parse_qs(parsed.query).get('IDALBO', [''])[0]))


def fetch(opener, url, data=None):
    request = Request(url, data=data, headers={'User-Agent': 'Mozilla/5.0', 'Referer': LISTING})
    for attempt in range(3):
        try:
            with opener.open(request, timeout=45) as response:
                page = Page()
                page.feed(response.read().decode(response.headers.get_content_charset() or 'utf-8'))
                return page
        except (URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(2)


def resolve(items, cache):
    pending = [item for item in items if not valid_link(cache.get(str(item['id']), ''))]
    print(f'Dettagli da recuperare: {len(pending)}/{len(items)}', file=sys.stderr)
    session = build_opener(HTTPCookieProcessor(http.cookiejar.CookieJar()))
    # Nessun CookieProcessor: i permalink devono aprirsi anche fuori dalla sessione.
    independent = build_opener()
    if pending:
        listing = fetch(session, LISTING)
        if not listing.target:
            raise ValueError('Tabella o postback non trovato nella pagina degli atti')
    for index, item in enumerate(items, 1):
        row_id = str(item['id'])
        link = cache.get(row_id, '')
        if not valid_link(link):
            fields = dict(listing.fields)
            fields['__EVENTTARGET'] = listing.target
            fields['__EVENTARGUMENT'] = json.dumps({'type': 'row_selected', 'row_id': row_id})
            detail = fetch(session, LISTING, urlencode(fields).encode())
            link = detail.share or ''
            if not valid_link(link):
                raise ValueError(f'Atto {row_id}: permalink assente o non valido')
            for attempt in range(3):
                check = fetch(independent, link)
                if (check.share and valid_link(check.share)
                        and parse_qs(urlsplit(check.share).query).get('IDALBO')
                        == parse_qs(urlsplit(link).query).get('IDALBO')):
                    break
                if attempt == 2:
                    raise ValueError(f'Atto {row_id}: permalink non apribile senza sessione')
                # La fonte può restituire temporaneamente l'elenco al posto del dettaglio.
                time.sleep(1)
            title = ' '.join(item['titolo'].split())
            if (not title or title not in ' '.join(' '.join(check.text).split())
                    or (check.document_ids and row_id not in check.document_ids)):
                raise ValueError(f'Atto {row_id}: il permalink apre un dettaglio diverso')
        item['link'] = link
        if index % 20 == 0 or index == len(items):
            print(f'Permalink risolti: {index}/{len(items)}', file=sys.stderr)
    return items


def main():
    input_path, feed_path = map(Path, sys.argv[1:])
    cache = {}
    if feed_path.exists():
        for item in ET.parse(feed_path).findall('./channel/item'):
            cache[item.findtext('guid', '')] = item.findtext('link', '')
    result = resolve(json.loads(input_path.read_text()), cache)
    json.dump(result, sys.stdout, ensure_ascii=False)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, ET.ParseError) as error:
        print(f'Errore recupero permalink: {error}', file=sys.stderr)
        sys.exit(1)
