#!/usr/bin/env python3
"""Generate Canonical Injection process guide (Word) for Taiwan team."""

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

SCRIPT_DIR = Path(__file__).resolve().parent
IMAGES_DIR = SCRIPT_DIR / "images"
OUTPUT_PATH = SCRIPT_DIR / "Canonical_Injection_Guide.docx"
SUCCESS_IMAGE = IMAGES_DIR / "canonical_success_mcw88.png"

DARK = RGBColor(0x1A, 0x1A, 0x1A)
ACCENT = RGBColor(0xD9, 0x77, 0x06)
MUTED = RGBColor(0x66, 0x66, 0x66)
CODE_BG = "F5F5F5"


def set_styles(doc: Document) -> None:
    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)
    style.paragraph_format.space_after = Pt(6)
    style.paragraph_format.line_spacing = 1.15


def heading(doc: Document, text: str, level: int = 1) -> None:
    h = doc.add_heading(text, level=level)
    for run in h.runs:
        run.font.color.rgb = DARK


def bullet(doc: Document, text: str) -> None:
    doc.add_paragraph(text, style="List Bullet")


def numbered(doc: Document, text: str) -> None:
    doc.add_paragraph(text, style="List Number")


def code_block(doc: Document, text: str) -> None:
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(8)
    run = p.add_run(text)
    run.font.name = "Consolas"
    run.font.size = Pt(9)

    p_pr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), CODE_BG)
    shd.set(qn("w:val"), "clear")
    p_pr.append(shd)


def add_figure(doc: Document, image_path: Path, caption: str, width: float = 6.2) -> None:
    if not image_path.exists():
        doc.add_paragraph(f"[Image missing: {image_path.name}]")
        return

    pic = doc.add_paragraph()
    pic.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pic.add_run().add_picture(str(image_path), width=Inches(width))

    cap = doc.add_paragraph()
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = cap.add_run(caption)
    run.italic = True
    run.font.size = Pt(10)
    run.font.color.rgb = MUTED


def build() -> Document:
    doc = Document()
    set_styles(doc)

    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = title.add_run("Canonical Injection Process")
    run.bold = True
    run.font.size = Pt(24)
    run.font.color.rgb = DARK

    sub = doc.add_paragraph()
    sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = sub.add_run("How Cloudflare Worker canonical injection works")
    run.font.size = Pt(13)
    run.font.color.rgb = ACCENT

    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = meta.add_run("Created by MCW SEO")
    run.font.size = Pt(11)
    run.font.color.rgb = MUTED

    doc.add_paragraph()

    # 1 Goal
    heading(doc, "1. Goal")
    doc.add_paragraph(
        "Change the page canonical tag without editing the website source code "
        "(WordPress, Laravel, static HTML, etc.)."
    )
    code_block(doc, '<link rel="canonical" href="https://mcw.live/">')
    doc.add_paragraph(
        "We do this at the Cloudflare edge with a Worker that rewrites HTML."
    )

    # 2 Idea
    heading(doc, "2. Core idea")
    doc.add_paragraph("Three Cloudflare pieces:")
    bullet(doc, "Worker script — rewrites HTML (insert/update canonical).")
    bullet(doc, "URL map — which page URL should get which canonical href.")
    bullet(doc, "Workers Route — which domain traffic goes through the Worker.")

    doc.add_paragraph("Request flow:")
    code_block(
        doc,
        "Browser\n"
        "   ↓\n"
        "Cloudflare Worker (seo-canonical-inject)\n"
        "   ↓ fetch origin HTML\n"
        "Origin website\n"
        "   ↓\n"
        "Worker rewrites <link rel=\"canonical\">\n"
        "   ↓\n"
        "Browser receives updated HTML",
    )

    # 3 Permissions
    heading(doc, "3. Required API permissions")
    bullet(doc, "Account → Workers Scripts → Edit")
    bullet(doc, "Zone → Workers Routes → Edit")
    bullet(doc, "Zone → Zone → Read")

    # 4 Process
    heading(doc, "4. Process (replicate this)")
    numbered(
        doc,
        "Create / update one Worker script (example name: seo-canonical-inject).",
    )
    numbered(
        doc,
        "Store a JSON map of source URL → canonical URL "
        "(plain-text binding CANONICAL_MAP_JSON).",
    )
    numbered(
        doc,
        "Attach a Workers Route on the zone: *domain.com/* → that Worker.",
    )
    numbered(
        doc,
        "When HTML is requested, Worker looks up the URL in the map and "
        "rewrites the canonical tag.",
    )
    numbered(
        doc,
        "Verify in browser DevTools / View Source that the tag is correct.",
    )

    # 5 Example
    heading(doc, "5. Working example")
    doc.add_paragraph("Target mapping:")
    code_block(doc, "https://mcw88.bio  →  https://mcw.live/")

    doc.add_paragraph("Map saved in the Worker:")
    code_block(
        doc,
        "{\n"
        '  "https://mcw88.bio/": "https://mcw.live/",\n'
        '  "__host__:mcw88.bio": "https://mcw.live/"\n'
        "}",
    )
    doc.add_paragraph(
        "__host__:mcw88.bio means every page on that hostname uses "
        "https://mcw.live/ as canonical (domain-wide rule)."
    )

    doc.add_paragraph("Workers Route on zone mcw88.bio:")
    code_block(doc, "*mcw88.bio/*  →  seo-canonical-inject")

    doc.add_paragraph("Live result in HTML:")
    code_block(doc, '<link rel="canonical" href="https://mcw.live/">')

    doc.add_paragraph(
        "Proof: Worker + route applied successfully, and DevTools on "
        "mcw88.bio shows canonical → https://mcw.live/."
    )
    add_figure(
        doc,
        SUCCESS_IMAGE,
        "Figure 1 — Live proof: https://mcw88.bio → https://mcw.live/",
    )

    # 6 Map rules
    heading(doc, "6. Mapping rules we use")
    bullet(doc, "Exact page URL → specific canonical href.")
    bullet(
        doc,
        "Domain home URL (https://site.com/) also writes __host__:site.com "
        "so the whole hostname uses that canonical.",
    )
    bullet(
        doc,
        "If right side is blank, canonical = the page URL itself.",
    )
    bullet(
        doc,
        "If only one canonical is given for many source URLs, that one "
        "canonical applies to all of them.",
    )

    # 7 Worker code
    heading(doc, "7. Worker code")
    doc.add_paragraph(
        "Core Worker logic (HTMLRewriter). Non-HTML responses are ignored."
    )
    code_block(
        doc,
        "export default {\n"
        "  async fetch(request, env) {\n"
        "    const response = await fetch(request);\n"
        "    const type = response.headers.get(\"content-type\") || \"\";\n"
        "    if (!type.includes(\"text/html\")) return response;\n"
        "\n"
        "    const map = JSON.parse(env.CANONICAL_MAP_JSON || \"{}\");\n"
        "    const canonical = lookupCanonical(map, request.url);\n"
        "    if (!canonical) return response; // no rule → leave HTML as-is\n"
        "\n"
        "    const linkHandler = new CanonicalElementHandler(canonical);\n"
        "    return new HTMLRewriter()\n"
        "      .on('link[rel=\"canonical\"]', linkHandler) // update existing\n"
        "      .on(\"head\", new HeadHandler(linkHandler))   // insert if missing\n"
        "      .transform(response);\n"
        "  }\n"
        "};",
    )

    doc.add_paragraph("Lookup order inside lookupCanonical():")
    numbered(doc, "Match exact request URL (slash / no-slash variants).")
    numbered(doc, "Else match __host__:hostname (and www variant).")
    numbered(doc, "Else return null (do not change HTML).")

    doc.add_paragraph("Update existing tag:")
    code_block(
        doc,
        "class CanonicalElementHandler {\n"
        "  element(element) {\n"
        "    element.setAttribute(\"href\", this.canonical);\n"
        "    this.found = true;\n"
        "  }\n"
        "}",
    )

    doc.add_paragraph("Insert tag if page has none:")
    code_block(
        doc,
        "element.onEndTag((end) => {\n"
        "  if (!linkHandler.found) {\n"
        "    end.before(\n"
        "      `<link rel=\"canonical\" href=\"${linkHandler.canonical}\" />`,\n"
        "      { html: true }\n"
        "    );\n"
        "  }\n"
        "});",
    )

    # 8 Upload Worker (API)
    heading(doc, "8. Deploy Worker (API)")
    doc.add_paragraph(
        "Upload as a module Worker with multipart form. Include the JS file "
        "and metadata with the map binding."
    )
    code_block(
        doc,
        "PUT /accounts/{account_id}/workers/scripts/seo-canonical-inject\n"
        "\n"
        "metadata JSON:\n"
        "{\n"
        '  "main_module": "worker.js",\n'
        '  "compatibility_date": "2024-09-23",\n'
        '  "bindings": [{\n'
        '    "type": "plain_text",\n'
        '    "name": "CANONICAL_MAP_JSON",\n'
        '    "text": "{\\"https://mcw88.bio/\\":\\"https://mcw.live/\\",'
        '\\"__host__:mcw88.bio\\":\\"https://mcw.live/\\"}"\n'
        "  }]\n"
        "}",
    )

    # 9 Route API
    heading(doc, "9. Attach / rewrite route (API)")
    doc.add_paragraph(
        "Create route if missing. If it already exists, rewrite (PUT) it — "
        "do not skip."
    )
    code_block(
        doc,
        "POST /zones/{zone_id}/workers/routes\n"
        "{\n"
        '  "pattern": "*mcw88.bio/*",\n'
        '  "script": "seo-canonical-inject"\n'
        "}\n"
        "\n"
        "PUT /zones/{zone_id}/workers/routes/{route_id}\n"
        "(same body — use this to rewrite an existing route)",
    )
    doc.add_paragraph(
        "Use pattern *domain.com/* (leading *). "
        "Pattern domain.com/* alone is not enough for reliable coverage."
    )

    # 10 Conditions
    heading(doc, "10. Conditions")
    bullet(doc, "Domain must be on Cloudflare.")
    bullet(doc, "DNS must be proxied (orange cloud). Grey cloud = Worker will not run.")
    bullet(doc, "Zone should be Active.")
    bullet(doc, "Hard refresh after deploy when verifying.")

    # 11 Verify
    heading(doc, "11. How to verify")
    numbered(doc, "Workers & Pages → seo-canonical-inject exists.")
    numbered(doc, "Zone → Workers Routes → *domain.com/* → seo-canonical-inject.")
    numbered(doc, "Open https://mcw88.bio → hard refresh.")
    numbered(
        doc,
        "DevTools Elements / View Source shows "
        '<link rel="canonical" href="https://mcw.live/">',
    )

    end = doc.add_paragraph()
    end.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = end.add_run("— MCW SEO —")
    run.italic = True
    run.font.color.rgb = MUTED

    return doc


def main() -> None:
    doc = build()
    doc.save(OUTPUT_PATH)
    print(f"Created: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
