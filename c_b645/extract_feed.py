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

        # Extract text content for parsing items
        content = tree.xpath('//body')[0].text_content()

        # Find the section containing the actual data (same as before)
        data_start_marker = "Fine Pubblicazione"
        data_end_marker = "1 2 3 4 5 > >>"

        start_index = content.find(data_start_marker)
        end_index = content.find(data_end_marker)

        extracted_data_text = ""
        if start_index != -1 and end_index != -1 and end_index > start_index:
            extracted_data_text = content[start_index + len(data_start_marker):end_index].strip()
        elif start_index != -1:
            extracted_data_text = content[start_index + len(data_start_marker):].strip()

        # Split the text into potential items.
        item_pattern = re.compile(r"^(\d{4}/\d{7}.*)", re.MULTILINE)
        items_raw = item_pattern.findall(extracted_data_text)

        # Debugging: Print all <a> tags text and href
        all_links = tree.xpath('//a')
        print("DEBUG: All links on page:", file=sys.stderr)
        for a_tag in all_links:
            print(f"  Text: '{a_tag.text_content().strip()}', Href: '{a_tag.get('href')}'", file=sys.stderr)
        print("DEBUG: End of all links.", file=sys.stderr)

        rss_items = []
        for item_text in items_raw:
            parts = item_text.strip().split('\t')
            
            if len(parts) >= 5:
                number = parts[0].strip()
                obj = parts[1].strip()
                act_type = parts[2].strip()
                date_affissione = parts[3].strip()
                fine_pubblicazione = parts[4].strip()

                # Now, find the corresponding link from the HTML
                link_xpath = "//a[text()='{}' and contains(@href, 'albo_dettagli.php?id=')]”.format(number)
                link_element = tree.xpath(link_xpath)

                link_url = ""
                if link_element:
                    link_url = link_element[0].get('href')
                    if not link_url.startswith("http"):
                        link_url = "https://servizi.comune.capaci.pa.it/openweb/albo/" + link_url


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
