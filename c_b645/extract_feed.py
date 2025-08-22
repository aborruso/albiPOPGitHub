import asyncio
import re
from playwright.async_api import async_playwright
from datetime import datetime
import sys
from lxml import html # Import lxml

async def extract_feed():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        await page.goto("https://servizi.comune.capaci.pa.it/openweb/albo/albo_pretorio.php")

        # Wait for some time to ensure all content is loaded
        await asyncio.sleep(2)

        # Get full HTML content
        html_content = await page.content()

        await browser.close()

        # Parse HTML with lxml
        tree = html.fromstring(html_content)

        rss_items = []
        # Find all table rows in the body of the table with id 'tabella_albo'
        rows = tree.xpath('//table[@id="tabella_albo"]/tbody/tr')

        for row in rows:
            cells = row.xpath('./td')
            if len(cells) >= 5:
                # Extract link and number from the first cell
                link_element = cells[0].find('.//a')
                if link_element is not None:
                    link_url = link_element.get('href')
                    if not link_url.startswith("http"):
                        link_url = "https://servizi.comune.capaci.pa.it/openweb/albo/" + link_url
                else:
                    continue # Skip row if no link

                obj = cells[1].text_content().strip()
                date_affissione = cells[3].text_content().strip()

                title = obj
                
                try:
                    pub_date = datetime.strptime(date_affissione, "%d/%m/%Y").strftime("%a, %d %b %Y %H:%M:%S GMT")
                except ValueError:
                    pub_date = datetime.now().strftime("%a, %d %b %Y %H:%M:%S GMT")

                # Only add item if a valid link is found
                if link_url:
                    rss_items.append(f"""    <item>
        <title>{title}</title>
        <link>{link_url}</link>
        <guid isPermaLink=\"false\">{link_url}</guid>
        <pubDate>{pub_date}</pubDate>
    </item>
""")

        rss_header = f"""<?xml version=\"1.0\" encoding=\"utf-8\"?>
<rss version=\"2.0">
<channel>
    <title>AlboPOP del comune di Capaci</title>
    <link>https://servizi.comune.capaci.pa.it/openweb/albo/albo_pretorio.php</link>
    <description>Feed RSS degli atti pubblicati sull'Albo Pretorio del Comune di Capaci</description>
    <generator>Custom Python Script</generator>"""

        rss_footer = """</channel>
</rss>"""

        print(rss_header)
        print("\n".join(rss_items))
        print(rss_footer)

if __name__ == "__main__":
    asyncio.run(extract_feed())
