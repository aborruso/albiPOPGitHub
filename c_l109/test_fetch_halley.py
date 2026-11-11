import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

from fetch_halley import parse_cards, collect, read_cache, verify_document, BASE

CARD = '''<div class="card"><div class="category-top"><span>Pubblicazione n. 2293</span></div>
<a onclick="MC02('1')"><h5>Viabilità &amp; lavori</h5></a>
<div><span><strong>Mittente:</strong> Settore IV</span></div>
<div><span><strong>Tipo:</strong> ORDINANZA</span></div>
<div><span><strong>Pubblicazione dal </strong>11-11-2026 <strong>al </strong>26-11-2026</span></div>
</div><span id="totalePagine">1</span>'''
DETAIL = '''<h1>Pubblicazione n. 2293/2026</h1><p>Viabilità &amp; lavori</p>
<a onclick="MC98(1)">Ordinanza.pdf</a><a onclick="MC99(1)">Allegato.pdf</a>'''
DOC = BASE + '/halley/ht/e1380/DOCR973188.pdf'


class Client:
    def __init__(self):
        self.calls = []
    def post(self, function, **params):
        self.calls.append((function, params))
        if function == 'MC01':
            return CARD
        if function == 'MC02':
            return DETAIL
        return '{"K":"000","PATH":"' + DOC + '"}'


class HalleyTest(unittest.TestCase):
    def test_native_scrape_extracts_metadata(self):
        items = parse_cards(CARD)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]['titolo'], 'Viabilità & lavori')
        self.assertEqual(items[0]['id'], '2026-2293')
        self.assertEqual(items[0]['position'], '1')
        self.assertIn('11 Nov 2026', items[0]['pubDate'])

    def test_collect_documents_and_preserve_complete_description(self):
        client = Client()
        with patch('fetch_halley.verify_document') as verify:
            items = collect(client, {})
        self.assertEqual(items[0]['link'], DOC)
        self.assertIn('data-documento="1"', items[0]['description'])
        self.assertIn('Settore IV', items[0]['description'])
        self.assertEqual(verify.call_count, 1)  # stesso URL deduplicato
        self.assertEqual([c[0] for c in client.calls], ['MC01', 'MC02', 'MC98', 'MC99'])

    def test_reuses_cached_documents(self):
        client = Client()
        cache = {'2026-2293': [{'name': 'Ordinanza.pdf', 'url': DOC}]}
        with patch('fetch_halley.verify_document') as verify:
            items = collect(client, cache)
        self.assertEqual(items[0]['link'], DOC)
        self.assertEqual([c[0] for c in client.calls], ['MC01'])
        verify.assert_called_once_with(DOC, head=True)

    def test_expired_cached_document_is_refreshed(self):
        client = Client()
        cache = {'2026-2293': [{'name': 'Ordinanza.pdf', 'url': DOC}]}
        with patch('fetch_halley.verify_document', side_effect=[OSError('404'), None]):
            items = collect(client, cache)
        self.assertEqual(items[0]['link'], DOC)
        self.assertIn('MC02', [c[0] for c in client.calls])

    def test_missing_page_is_an_error(self):
        client = Client()
        client.post = lambda *a, **kw: '<html>Errore</html>'
        with self.assertRaises(ValueError):
            collect(client, {})

    def test_wrong_detail_is_an_error(self):
        client = Client()
        original = client.post
        client.post = lambda f, **kw: '<h1>Pubblicazione n. 999/2026</h1>' if f == 'MC02' else original(f, **kw)
        with self.assertRaises(ValueError):
            collect(client, {})

    def test_html_instead_of_document_is_rejected(self):
        class Response(io.BytesIO):
            headers = {'Content-Type': 'text/html'}
        with patch('fetch_halley.urlopen', return_value=Response(b'<html>Denied</html>')):
            with self.assertRaises(ValueError):
                verify_document(DOC)

    def test_official_html_attachment_is_valid(self):
        class Response(io.BytesIO):
            headers = {'Content-Type': 'text/html'}
        with patch('fetch_halley.urlopen', return_value=Response(b'<!DOCTYPE html><html>Documento allegato</html>')):
            verify_document(DOC.replace('.pdf', '.html'))

    def test_returns_to_list_before_next_page_and_stops_at_limit(self):
        class PagedClient:
            def __init__(self):
                self.calls = []
            def post(self, function, **params):
                self.calls.append(function)
                if function == 'MC01':
                    return CARD.replace('id="totalePagine">1', 'id="totalePagine">42')
                if function == 'MC08':
                    return '<html/>'
                if function == 'PMC02':
                    if self.calls[-2] != 'MC08':
                        raise AssertionError('Occorre prima tornare all’elenco')
                    return CARD.replace('2293', '2292')
                raise AssertionError(function)
        client = PagedClient()
        cache = {key: [{'url': DOC, 'name': 'Documento.pdf'}] for key in ('2026-2293', '2026-2292')}
        with patch('fetch_halley.verify_document'):
            result = collect(client, cache, limit=2)
        self.assertEqual(len(result), 2)
        self.assertEqual(client.calls, ['MC01', 'MC08', 'PMC02'])

    def test_document_get_does_not_use_blocked_range_header(self):
        class Response(io.BytesIO):
            headers = {'Content-Type': 'application/pdf'}
        with patch('fetch_halley.urlopen', return_value=Response(b'%PDF-1.7')) as request:
            verify_document(DOC)
        self.assertNotIn('Range', request.call_args.args[0].headers)

    def test_cache_from_feed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'feed.xml'
            root = ET.Element('rss'); item = ET.SubElement(ET.SubElement(root, 'channel'), 'item')
            ET.SubElement(item, 'guid').text = 'urn:albopop:c_l109:2026-2293'
            ET.SubElement(item, 'description').text = f'<a data-documento="1" href="{DOC}">Ordinanza.pdf</a>'
            ET.ElementTree(root).write(path, encoding='utf-8')
            self.assertEqual(read_cache(path)['2026-2293'][0]['url'], DOC)


if __name__ == '__main__':
    unittest.main()
