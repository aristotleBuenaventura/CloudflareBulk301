#!/usr/bin/env python3
"""Generate SEO 301 Redirects user guide Word document."""

from pathlib import Path
from typing import Optional

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt, RGBColor
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

SCRIPT_DIR = Path(__file__).resolve().parent
IMAGES_DIR = SCRIPT_DIR / "images"
OUTPUT_PATH = SCRIPT_DIR / "SEO_301_Redirect_User_Guide.docx"

DOWNLOAD_URL = (
    "https://drive.google.com/file/d/1UV4GZh9scocTan67UWmKUB5s9foj32DR/view?usp=sharing"
)

ACCENT = RGBColor(0xD9, 0x77, 0x06)
DARK = RGBColor(0x1A, 0x1A, 0x1A)
MUTED = RGBColor(0x66, 0x66, 0x66)


def set_document_styles(doc: Document) -> None:
    style = doc.styles["Normal"]
    font = style.font
    font.name = "Calibri"
    font.size = Pt(11)
    style.paragraph_format.space_after = Pt(6)
    style.paragraph_format.line_spacing = 1.15


def add_horizontal_line(paragraph) -> None:
    p = paragraph._p
    p_pr = p.get_or_add_pPr()
    p_bdr = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), "6")
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), "D97706")
    p_bdr.append(bottom)
    p_pr.append(p_bdr)


def add_title_page(doc: Document) -> None:
    for _ in range(4):
        doc.add_paragraph()

    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = title.add_run("SEO 301 Redirects")
    run.bold = True
    run.font.size = Pt(28)
    run.font.color.rgb = DARK

    subtitle = doc.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = subtitle.add_run("User Guide")
    run.font.size = Pt(16)
    run.font.color.rgb = ACCENT

    doc.add_paragraph()

    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = meta.add_run(
        "How to create a Cloudflare API token,\n"
        "install the desktop app, and apply bulk 301 redirects.\n\n"
        "Version 1.1.0  |  July 2026"
    )
    run.font.size = Pt(11)
    run.font.color.rgb = MUTED

    doc.add_page_break()


def add_heading(doc: Document, text: str, level: int = 1) -> None:
    heading = doc.add_heading(text, level=level)
    for run in heading.runs:
        run.font.color.rgb = DARK


def add_bullet(doc: Document, text: str, bold_prefix: Optional[str] = None) -> None:
    p = doc.add_paragraph(style="List Bullet")
    if bold_prefix:
        run = p.add_run(bold_prefix)
        run.bold = True
        p.add_run(text)
    else:
        p.add_run(text)


def add_numbered(doc: Document, text: str, bold_prefix: Optional[str] = None) -> None:
    p = doc.add_paragraph(style="List Number")
    if bold_prefix:
        run = p.add_run(bold_prefix)
        run.bold = True
        p.add_run(text)
    else:
        p.add_run(text)


def add_callout(doc: Document, title: str, body: str) -> None:
    p = doc.add_paragraph()
    run = p.add_run(title)
    run.bold = True
    run.font.color.rgb = ACCENT
    doc.add_paragraph(body)


def add_figure(
    doc: Document,
    image_name: str,
    figure_num: int,
    caption: str,
    width: float = 6.0,
) -> None:
    image_path = IMAGES_DIR / image_name
    if not image_path.exists():
        doc.add_paragraph(f"[Figure {figure_num} image not found: {image_name}]")
        return

    doc.add_paragraph()
    pic_para = doc.add_paragraph()
    pic_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = pic_para.add_run()
    run.add_picture(str(image_path), width=Inches(width))

    cap = doc.add_paragraph()
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap_run = cap.add_run(f"Figure {figure_num} — {caption}")
    cap_run.italic = True
    cap_run.font.size = Pt(10)
    cap_run.font.color.rgb = MUTED
    doc.add_paragraph()


def add_red_box_note(doc: Document, items: list[tuple[str, str]]) -> None:
    """Add highlighted action items (red box guides)."""
    p = doc.add_paragraph()
    run = p.add_run("Highlighted actions (red boxes in screenshot):")
    run.bold = True
    run.font.color.rgb = RGBColor(0xB9, 0x1C, 0x1C)

    for label, description in items:
        bp = doc.add_paragraph(style="List Bullet")
        r = bp.add_run(f"{label}: ")
        r.bold = True
        bp.add_run(description)


def build_document() -> Document:
    doc = Document()
    set_document_styles(doc)
    add_title_page(doc)

    # Overview
    add_heading(doc, "Overview")
    doc.add_paragraph(
        "SEO 301 Redirects is a Windows desktop application that lets you apply "
        "permanent (301) redirects across many Cloudflare-managed domains in one "
        "workflow. This guide walks you through the complete process:"
    )
    overview_steps = [
        "Creating a Cloudflare API token with the correct permissions and IP restrictions.",
        "Downloading and running the application from the provided Google Drive link.",
        "Signing in with your API token.",
        "Configuring source domains and a target domain, then applying bulk 301 redirects.",
    ]
    for step in overview_steps:
        add_numbered(doc, step)

    add_callout(
        doc,
        "Important — Security note: ",
        "Your API token is kept in memory only while the app is open. It is never "
        "saved to disk. For best security, restrict the token to your current IP "
        "address using Cloudflare's Client IP Address Filtering.",
    )

    doc.add_page_break()

    # Part 1: Cloudflare API Token
    add_heading(doc, "Part 1 — Create a Cloudflare API Token")
    doc.add_paragraph(
        "Before using the app, you need a Cloudflare User API token with specific "
        "permissions. User tokens create Page Rules for redirects. Follow each step "
        "below; red boxes in the screenshots indicate exactly what to click or fill in."
    )

    add_heading(doc, "Step 1: Open API Tokens in your Cloudflare profile", level=2)
    doc.add_paragraph(
        "Log in to the Cloudflare dashboard at https://dash.cloudflare.com. "
        "Click your profile icon (top right), then select My Profile. "
        "In the left sidebar, click API Tokens."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — API Tokens",
                "Click this menu item in the left sidebar to open the token management page.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig01_profile_api_tokens.png",
        1,
        "Navigate to API Tokens from your Cloudflare profile",
    )

    add_heading(doc, "Step 2: Start creating a new token", level=2)
    doc.add_paragraph(
        "On the User API Tokens page, click the Create Token button to begin."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — + Create Token",
                "Click this blue button in the top-right corner of the page.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig02_create_token.png",
        2,
        "Click Create Token on the User API Tokens page",
    )

    add_heading(doc, "Step 3: Choose Custom token", level=2)
    doc.add_paragraph(
        "Cloudflare offers pre-built templates, but this app requires a custom token "
        "with specific permissions. Under Custom token, click Get started."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Get started",
                "Click this button next to Custom token (not the template buttons below).",
            ),
        ],
    )
    add_figure(
        doc,
        "fig03_custom_token.png",
        3,
        "Select Custom token and click Get started",
    )

    add_heading(doc, "Step 4: Name your token", level=2)
    doc.add_paragraph(
        "Enter a descriptive name so you can identify this token later in Cloudflare "
        "Audit Logs (for example, SEO 301 Redirects or your name)."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Token name",
                "Type a clear, memorable name in this field.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig04_token_name.png",
        4,
        "Enter a descriptive token name",
    )

    add_heading(doc, "Step 5: Set the required permissions", level=2)
    doc.add_paragraph(
        "The app needs three zone-level permissions. Click + Add more to add each row "
        "if needed, then set the dropdowns exactly as shown:"
    )
    permissions = [
        "Zone → Single Redirect → Edit",
        "Zone → Zone → Read",
        "Zone → Page Rules → Edit",
    ]
    for perm in permissions:
        add_bullet(doc, perm)

    doc.add_paragraph(
        "Under Zone Resources, leave the default: Include → All zones (or restrict "
        "to specific zones if you prefer least-privilege access)."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Permissions section",
                "Configure all three permission rows inside this highlighted area.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig05_permissions.png",
        5,
        "Configure the three required zone permissions",
    )

    add_heading(doc, "Step 6: Restrict the token to your IP address", level=2)
    doc.add_paragraph(
        "Client IP Address Filtering limits which IP addresses can use this token. "
        "This is strongly recommended — if the token is ever exposed, it cannot be "
        "used from another network."
    )
    doc.add_paragraph(
        "Tip: When you open the SEO 301 Redirects app later, the login screen displays "
        "your current public IPv4 and IPv6 addresses. Add those same addresses here."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box 1 — Operator",
                "Set this dropdown to Is in.",
            ),
            (
                "Red box 2 — Value",
                "Enter your public IP address (e.g. 110.235.164.189).",
            ),
            (
                "Red box 3 — Use my IP",
                "Alternatively, click this button to auto-fill your current public IP.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig06_ip_filtering.png",
        6,
        "Configure Client IP Address Filtering for your public IP",
    )

    add_heading(doc, "Step 7: Review and continue", level=2)
    doc.add_paragraph(
        "Verify your token name, permissions, zone resources, and IP filter. "
        "Leave TTL (expiration) blank unless your organization requires a fixed expiry date. "
        "When everything looks correct, click Continue to summary."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Continue to summary",
                "Click this blue button at the bottom of the form.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig07_continue_summary.png",
        7,
        "Review settings and click Continue to summary",
    )

    add_heading(doc, "Step 8: Confirm and create the token", level=2)
    doc.add_paragraph(
        "The summary page shows all accounts, zones, and permissions affected by this "
        "token. Confirm that permissions include Single Redirect:Edit, Zone:Read, and "
        "Page Rules:Edit, and that your IP address appears under Client IP Address Filtering."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Create Token",
                "Click this button to generate the token.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig08_create_token_confirm.png",
        8,
        "Review the summary and click Create Token",
    )

    add_heading(doc, "Step 9: Copy and save your token", level=2)
    doc.add_paragraph(
        "Cloudflare displays your new API token once. Copy it immediately and store it "
        "in a secure location (password manager or secure notes). You will paste this "
        "token into the app in Part 3."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — API token string",
                "Copy this entire token value. It will not be shown again after you leave this page.",
            ),
        ],
    )
    doc.add_paragraph(
        "Optional: Use the curl command shown on this page to verify the token works "
        "before proceeding."
    )
    add_figure(
        doc,
        "fig09_copy_token.png",
        9,
        "Copy your API token — it is shown only once",
    )

    doc.add_page_break()

    # Part 2: Download & Install
    add_heading(doc, "Part 2 — Download, Extract, and Run the App")
    doc.add_paragraph(
        "Download the application package from Google Drive, extract it, and launch "
        "the executable."
    )

    add_heading(doc, "Step 10: Download the application", level=2)
    doc.add_paragraph(
        f"Open the following link in your browser and download the ZIP file:\n{DOWNLOAD_URL}"
    )
    doc.add_paragraph(
        "The file is named SEO_301_Redirect_v1.1.0 (a compressed ZIP folder). "
        "It will typically save to your Downloads folder."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — SEO_301_Redirect_v1.1.0",
                "Locate this downloaded ZIP file in your Downloads folder.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig10_download_zip.png",
        10,
        "Locate the downloaded ZIP file in Downloads",
    )

    add_heading(doc, "Step 11: Extract the ZIP archive", level=2)
    doc.add_paragraph(
        "Right-click the ZIP file (or open it) and use Windows Extract all to unzip "
        "the contents."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Extract all",
                "Click this button in the File Explorer toolbar.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig11_extract_all.png",
        11,
        "Click Extract all to unzip the package",
    )

    doc.add_paragraph(
        "In the extraction dialog, confirm the destination folder (default is fine) "
        "and click Extract. Keep Show extracted files when complete checked."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Extract",
                "Click Extract to begin unzipping.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig12_extract_dialog.png",
        12,
        "Confirm destination and click Extract",
    )

    add_heading(doc, "Step 12: Open the Release folder", level=2)
    doc.add_paragraph(
        "After extraction, open the SEO_301_Redirect_v1.1.0 folder, then open the "
        "Release subfolder. This folder contains the application executable and "
        "required support files."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — Release",
                "Double-click this folder to open it.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig13_release_folder.png",
        13,
        "Open the Release folder inside the extracted package",
    )

    add_heading(doc, "Step 13: Launch the application", level=2)
    doc.add_paragraph(
        "Inside the Release folder, double-click SEO 301 Redirects to start the app. "
        "Do not move or delete the other files in this folder (DLLs and the data folder) "
        "— they are required for the app to run."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box — SEO 301 Redirects",
                "Double-click this executable to launch the application.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig14_run_executable.png",
        14,
        "Double-click SEO 301 Redirects to run the app",
    )

    doc.add_page_break()

    # Part 3: Sign In
    add_heading(doc, "Part 3 — Sign In with Your API Token")
    doc.add_paragraph(
        "When the app opens, you will see the login screen. Paste the Cloudflare API "
        "token you created in Part 1 and connect."
    )

    add_heading(doc, "Step 14: Paste your token and connect", level=2)
    doc.add_paragraph(
        "Before connecting, check the Add these IPs to your token allowlist section. "
        "If you did not add these IP addresses when creating the token, go back to "
        "Cloudflare, edit the token, and add them. Use the refresh icon if your "
        "network changed."
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box 1 — Cloudflare API Token",
                "Paste the token you copied in Step 9 into this field. Use the eye icon to show or hide the token.",
            ),
            (
                "Red box 2 — Connect",
                "Click Connect to validate the token and open the bulk redirect workspace.",
            ),
        ],
    )
    doc.add_paragraph(
        "Note at the bottom of the screen: User tokens create Page Rules. "
        "Account (cfat_) tokens use Redirect Rules instead. This guide uses a User token."
    )
    add_figure(
        doc,
        "fig15_login_screen.png",
        15,
        "Paste your API token and click Connect",
    )

    doc.add_page_break()

    # Part 4: Apply Redirects
    add_heading(doc, "Part 4 — Apply Bulk 301 Redirects")
    doc.add_paragraph(
        "After a successful login, the main workspace opens. Configure your redirect "
        "settings on the left panel; results appear on the right after you apply."
    )

    add_heading(doc, "Step 15: Configure and apply redirects", level=2)
    doc.add_paragraph(
        "Work through each numbered area in the screenshot:"
    )
    add_red_box_note(
        doc,
        [
            (
                "Red box 1 — Target domain",
                "Enter the destination URL where all traffic should be sent "
                "(e.g. https://newdomain.com). Include https://.",
            ),
            (
                "Red box 2 — Wildcard",
                "Keep this checked to redirect all paths on each source domain. "
                "Pattern: *domain.com/* → https://target.com/$2",
            ),
            (
                "Red box 3 — Source domains (manual)",
                "Type an old domain name (e.g. olddomain.com) and click Add. "
                "Repeat for each domain, or use CSV upload instead.",
            ),
            (
                "Red box 4 — Upload CSV",
                "Click to import domains from a CSV file. Format: one domain per line, "
                "or a column named domain.",
            ),
            (
                "Red box 5 — Apply 301 redirects",
                "When target and source domains are set, click this button to start. "
                "Progress and per-domain results appear on the right.",
            ),
            (
                "Red box 6 — Cloudflare user token",
                "Shows your current session type. Click the logout icon to end the "
                "session and return to the login screen.",
            ),
        ],
    )
    add_figure(
        doc,
        "fig16_bulk_redirect.png",
        16,
        "Configure target domain, source domains, and apply 301 redirects",
    )

    add_heading(doc, "Understanding results", level=2)
    doc.add_paragraph(
        "After you click Apply 301 redirects, the Results panel on the right shows "
        "the status for each domain:"
    )
    result_types = [
        ("Success", " — Redirect rule was created or updated."),
        ("Skipped", " — Domain was already configured or not found in your account."),
        ("Failed", " — An error occurred (check the message; common causes include wrong zone permissions or IP not on the token allowlist)."),
    ]
    for label, desc in result_types:
        add_bullet(doc, desc, bold_prefix=label)

    doc.add_page_break()

    # Troubleshooting
    add_heading(doc, "Troubleshooting")
    issues = [
        (
            "Login fails / authentication error",
            "Confirm the token is copied in full with no extra spaces. "
            "Verify your current public IP is on the token allowlist (see the login screen). "
            "Ensure the token has not expired if you set a TTL.",
        ),
        (
            "Domain not found",
            "The domain must exist as a zone in the same Cloudflare account tied to the token.",
        ),
        (
            "Permission denied",
            "Re-check Part 1, Step 5 — all three permissions must be set correctly.",
        ),
        (
            "App will not start",
            "Run the executable from inside the Release folder without moving DLL files. "
            "On Windows, allow the app if SmartScreen prompts you (the app is not signed).",
        ),
    ]
    for title, fix in issues:
        p = doc.add_paragraph()
        run = p.add_run(title)
        run.bold = True
        doc.add_paragraph(fix)

    # Quick reference
    add_heading(doc, "Quick Reference")
    ref_items = [
        ("Download link: ", DOWNLOAD_URL),
        ("Token permissions: ", "Zone → Single Redirect → Edit; Zone → Zone → Read; Zone → Page Rules → Edit"),
        ("Redirect pattern (wildcard on): ", "*source-domain/* → https://target-domain/$2"),
        ("CSV format: ", "One domain per line, or a column named domain"),
        ("Token storage: ", "In memory only — never saved to disk"),
    ]
    for prefix, text in ref_items:
        p = doc.add_paragraph(style="List Bullet")
        run = p.add_run(prefix)
        run.bold = True
        p.add_run(text)

    doc.add_paragraph()
    closing = doc.add_paragraph()
    add_horizontal_line(closing)
    footer = doc.add_paragraph()
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("— End of User Guide —")
    run.italic = True
    run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

    return doc


def main() -> None:
    doc = build_document()
    doc.save(OUTPUT_PATH)
    print(f"Created: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
