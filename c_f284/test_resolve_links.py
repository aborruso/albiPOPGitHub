import unittest
from unittest.mock import patch

from resolve_links import Page, resolve, valid_link

BASE = 'https://servizionline.comune.molfetta.ba.it/cmsmolfetta/portale/albopretorio/albopretorioconsultazione.aspx'
LINK = BASE + '?IDALBO=1INP%2ba7mDNU%3d'
ITEM = {'id': '56975', 'titolo': 'Ordinanza & viabilità', 'data': '11/11/2026'}


def page(html):
    result = Page()
    result.feed(html)
    return result


def detail(row_id='56975', title='Ordinanza &amp; viabilità'):
    return page(f'''<h1>Pubblicazione all'albo pretorio n. 3071/2026</h1>
    <p>{title}</p><input id="prefix_txtUrlShare" value="{LINK}">
    <a href="getfile.aspx?SOURCE=DB&amp;PARAM={row_id}&amp;KEY=126102">Documento</a>''')


class LinksTest(unittest.TestCase):
    def test_only_real_local_detail_urls(self):
        self.assertTrue(valid_link(LINK))
        for url in [BASE + '?P=400#56975', BASE + '?IDALBO=',
                    'https://example.com/?IDALBO=abc',
                    BASE + '.wrong?IDALBO=abc', BASE.replace('https:', 'http:') + '?IDALBO=abc']:
            self.assertFalse(valid_link(url), url)

    def test_postback_then_cookie_free_verification(self):
        listing = page('''<input type="hidden" name="__VIEWSTATE" value="state">
        <input id="prefix_tab_risultati_table_hidden_row_56975" type="hidden" name="row">''')
        with patch('resolve_links.fetch', side_effect=[listing, detail(), detail()]) as fetch:
            result = resolve([dict(ITEM)], {})
        self.assertEqual(result[0]['link'], LINK)
        self.assertIn(b'__EVENTTARGET=prefix_tab_risultati_table', fetch.call_args_list[1].args[2])
        self.assertIsNot(fetch.call_args_list[1].args[0], fetch.call_args_list[2].args[0])

    def test_temporary_missing_detail_is_retried(self):
        listing = page('<input id="prefix_hidden_row_56975" type="hidden" name="row">')
        with patch('resolve_links.fetch', side_effect=[listing, detail(), page('<html/>'), detail()]), patch('resolve_links.time.sleep'):
            result = resolve([dict(ITEM)], {})
        self.assertEqual(result[0]['link'], LINK)

    def test_unavailable_detail_is_not_published(self):
        listing = page('<input id="prefix_hidden_row_56975" type="hidden" name="row">')
        with patch('resolve_links.fetch', side_effect=[listing, detail(), page('<html/>'), page('<html/>'), page('<html/>')]), patch('resolve_links.time.sleep'):
            with self.assertRaises(ValueError):
                resolve([dict(ITEM)], {})

    def test_wrong_act_rejected(self):
        listing = page('<input id="prefix_hidden_row_56975" type="hidden" name="row">')
        with patch('resolve_links.fetch', side_effect=[listing, detail(), detail('123')]):
            with self.assertRaises(ValueError):
                resolve([dict(ITEM)], {})

    def test_missing_permalink_rejected(self):
        listing = page('<input id="prefix_hidden_row_56975" type="hidden" name="row">')
        with patch('resolve_links.fetch', side_effect=[listing, page('<html>Errore</html>')]):
            with self.assertRaises(ValueError):
                resolve([dict(ITEM)], {})

    def test_invalid_old_fragment_is_not_reused(self):
        listing = page('<input id="prefix_hidden_row_56975" type="hidden" name="row">')
        with patch('resolve_links.fetch', side_effect=[listing, detail(), detail()]) as fetch:
            result = resolve([dict(ITEM)], {'56975': BASE + '#56975'})
        self.assertEqual(fetch.call_count, 3)
        self.assertEqual(result[0]['link'], LINK)

    def test_valid_cached_link_requires_no_network(self):
        with patch('resolve_links.fetch') as fetch:
            result = resolve([dict(ITEM)], {'56975': LINK})
        fetch.assert_not_called()
        self.assertEqual(result[0]['link'], LINK)


if __name__ == '__main__':
    unittest.main()
