#!/usr/bin/env python3
"""Generate Cloudflare Bulk 301 proposal Word document."""

from pathlib import Path
from typing import Optional

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt, RGBColor
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

SCRIPT_DIR = Path(__file__).resolve().parent
IMAGE_PATH = SCRIPT_DIR / "cloudflare-bulk301-prototype.png"
OUTPUT_PATH = SCRIPT_DIR / "Cloudflare_Bulk_301_Proposal.docx"


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
    run = title.add_run("Cloudflare Bulk 301")
    run.bold = True
    run.font.size = Pt(28)
    run.font.color.rgb = RGBColor(0x1A, 0x1A, 0x1A)

    subtitle = doc.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = subtitle.add_run("Desktop Application Proposal")
    run.font.size = Pt(16)
    run.font.color.rgb = RGBColor(0xD9, 0x77, 0x06)

    doc.add_paragraph()

    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = meta.add_run("Internal Proposal Document\nPrepared for Management Review\nJune 2026")
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(0x66, 0x66, 0x66)

    doc.add_page_break()


def add_heading(doc: Document, text: str, level: int = 1) -> None:
    heading = doc.add_heading(text, level=level)
    for run in heading.runs:
        run.font.color.rgb = RGBColor(0x1A, 0x1A, 0x1A)


def add_bullet(doc: Document, text: str, bold_prefix: Optional[str] = None) -> None:
    p = doc.add_paragraph(style="List Bullet")
    if bold_prefix:
        run = p.add_run(bold_prefix)
        run.bold = True
        p.add_run(text)
    else:
        p.add_run(text)


def build_document() -> Document:
    doc = Document()
    set_document_styles(doc)
    add_title_page(doc)

    # Executive Summary
    add_heading(doc, "1. Executive Summary")
    doc.add_paragraph(
        "This document proposes the development of Cloudflare Bulk 301, a cross-platform "
        "desktop application for macOS and Windows. The application will enable operations "
        "teams to configure permanent (301) redirects across dozens of Cloudflare-managed "
        "domains in a single workflow, replacing repetitive manual configuration in the "
        "Cloudflare dashboard."
    )
    doc.add_paragraph(
        "The proposed solution is designed with security as a primary requirement: it runs "
        "locally as a desktop application, authenticates via Cloudflare API tokens with "
        "recommended IP restrictions, and never persists credentials to disk. Estimated "
        "processing time for 60 domains is approximately three minutes, significantly reducing "
        "operational overhead during domain migrations, consolidations, and portfolio-wide "
        "redirect campaigns."
    )

    # Problem Statement
    add_heading(doc, "2. Problem Statement")
    doc.add_paragraph(
        "Managing 301 redirects across a large portfolio of Cloudflare zones is time-consuming "
        "and error-prone when done manually. Each domain requires navigating to the correct "
        "zone, creating or updating redirect rules, and verifying the configuration. Based on "
        "current operations, configuring 60 domains manually takes approximately 20 minutes per "
        "batch — time that adds up quickly across repeated migrations and portfolio updates. "
        "Manual work also introduces inconsistency in redirect patterns."
    )
    doc.add_paragraph(
        "The proposed Cloudflare Bulk 301 application would reduce that same 60-domain batch to "
        "approximately three minutes — an estimated 85% reduction in processing time — while "
        "applying a uniform redirect pattern across every domain."
    )
    doc.add_paragraph(
        "Web-based internal tools introduce additional risk: they are exposed to the public "
        "internet, may store API credentials on servers, and expand the attack surface. A "
        "purpose-built desktop utility addresses both efficiency and security concerns."
    )

    # Proposed Solution
    add_heading(doc, "3. Proposed Solution")
    doc.add_paragraph(
        "Cloudflare Bulk 301 will be a native desktop application built with Flutter, "
        "supporting macOS and Windows from a single codebase. The workflow is intentionally "
        "simple:"
    )
    steps = [
        "Authenticate using a Cloudflare API token (session-only; not saved to disk).",
        "Specify a single target domain (e.g., example.com) to receive all traffic.",
        "Provide source domains manually or via CSV upload.",
        "Apply 301 redirects in bulk and review per-domain results (success, skipped, or failed).",
    ]
    for step in steps:
        add_bullet(doc, step)

    doc.add_paragraph(
        "The application will integrate directly with the Cloudflare API to look up zones, "
        "create or update Page Rules (or Redirect Rules where applicable), and report status "
        "for each domain in real time."
    )

    # Key Benefits
    add_heading(doc, "4. Key Benefits")
    benefits = [
        (
            "Reduced attack surface — ",
            "As a desktop application, the tool is not hosted online and cannot be accessed "
            "remotely via a public URL. Only authorized users with the installed application "
            "on their workstation can run it.",
        ),
        (
            "Token-based authentication — ",
            "Access is controlled through Cloudflare API tokens with scoped permissions "
            "(Zone Read, Page Rules / Redirect Rules Edit). No shared passwords or "
            "dashboard credentials are required.",
        ),
        (
            "IP-restricted token enforcement — ",
            "When Cloudflare token IP allowlisting is configured, a stolen token cannot be "
            "used from an unregistered IP address. The proposed login screen will display the "
            "user's current public IPv4 and IPv6 addresses to simplify allowlist setup.",
        ),
        (
            "No credential persistence — ",
            "API tokens are held in memory only for the active session. Closing the "
            "application clears the token. Nothing is written to local storage, configuration "
            "files, or logs.",
        ),
        (
            "Significant time savings — ",
            "Bulk processing is estimated to complete approximately 60 domains in three "
            "minutes, compared to the current manual process of approximately 20 minutes "
            "for the same batch. This enables faster migrations, rebranding rollouts, and "
            "domain consolidation projects.",
        ),
        (
            "Consistency and auditability — ",
            "A single target domain and uniform redirect pattern (*domain.com/* → "
            "https://target.com/$2) are applied consistently across all source domains, "
            "reducing configuration drift and human error.",
        ),
        (
            "Cross-platform deployment — ",
            "One application supports both macOS and Windows environments used across the team.",
        ),
    ]
    for prefix, text in benefits:
        add_bullet(doc, text, bold_prefix=prefix)

    # Security
    add_heading(doc, "5. Security Model")
    doc.add_paragraph(
        "Security is embedded in the architecture rather than added as an afterthought. "
        "The following controls are planned:"
    )

    add_heading(doc, "5.1 Authentication & Authorization", level=2)
    security_auth = [
        "Cloudflare API token required before any operation.",
        "Token validated against the Cloudflare API on login; invalid or expired tokens are rejected.",
        "Recommended token permissions: Zone → Read; Zone → Page Rules → Edit (or Redirect Rules Edit for account tokens).",
        "Token scoped to required zones only (principle of least privilege).",
    ]
    for item in security_auth:
        add_bullet(doc, item)

    add_heading(doc, "5.2 Credential Handling", level=2)
    security_cred = [
        "Tokens stored in application memory only — never saved to disk, registry, or cloud sync folders.",
        "Session ends when the application is closed; re-authentication required on next launch.",
        "No token transmission to third-party services; all API calls go directly to Cloudflare.",
    ]
    for item in security_cred:
        add_bullet(doc, item)

    add_heading(doc, "5.3 Network & Access Controls", level=2)
    security_net = [
        "Desktop-only deployment — no web server, no public endpoint, no remote access.",
        "Cloudflare token IP filtering supported and encouraged; stolen tokens are ineffective outside allowed IP ranges.",
        "Login screen displays current public IP addresses to streamline secure token configuration.",
        "All communication over HTTPS to api.cloudflare.com.",
    ]
    for item in security_net:
        add_bullet(doc, item)

    add_heading(doc, "5.4 Operational Security", level=2)
    security_ops = [
        "Per-domain result reporting enables immediate verification and error handling.",
        "Cloudflare Audit Logs (dashboard) record API actions attributable to the token name and source IP.",
        "CSV import supports batch operations without exposing domain lists to external services.",
    ]
    for item in security_ops:
        add_bullet(doc, item)

    # Prototype
    add_heading(doc, "6. Proposed User Interface (Prototype)")
    doc.add_paragraph(
        "The following mockup illustrates the intended user experience: a secure login screen "
        "with IP display for token allowlisting, and a bulk redirect workspace with target "
        "domain input, source domain list, CSV upload, and real-time results."
    )

    if IMAGE_PATH.exists():
        pic_para = doc.add_paragraph()
        pic_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = pic_para.add_run()
        run.add_picture(str(IMAGE_PATH), width=Inches(6.5))

        caption = doc.add_paragraph()
        caption.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cap_run = caption.add_run("Figure 1 — Proposed UI prototype (Login & Bulk 301 workflow)")
        cap_run.italic = True
        cap_run.font.size = Pt(10)
        cap_run.font.color.rgb = RGBColor(0x66, 0x66, 0x66)

    # Technical Overview
    add_heading(doc, "7. Technical Overview")
    tech_items = [
        ("Platform: ", "Flutter desktop (macOS, Windows)"),
        ("API Integration: ", "Cloudflare REST API (zone lookup, Page Rules / Redirect Rules)"),
        ("Input Methods: ", "Manual domain entry, CSV file upload"),
        ("Redirect Pattern: ", "*source-domain/* → https://target-domain/$2 (301 Permanent)"),
        ("Session Model: ", "In-memory API token; no persistent storage"),
    ]
    for prefix, text in tech_items:
        p = doc.add_paragraph(style="List Bullet")
        run = p.add_run(prefix)
        run.bold = True
        p.add_run(text)

    # Performance
    add_heading(doc, "8. Expected Performance")
    doc.add_paragraph(
        "Based on Cloudflare API rate considerations and planned throttling between requests, "
        "the application is expected to process bulk redirects at the following approximate rates:"
    )
    doc.add_paragraph(
        "Current manual process vs. proposed automated processing:"
    )
    perf = [
        "Manual (current): ~60 domains in approximately 20 minutes",
        "Proposed (Cloudflare Bulk 301): ~60 domains in approximately 3 minutes",
        "~100+ domains in under 5 minutes with the application",
        "Real-time per-domain status updates during processing",
    ]
    for item in perf:
        add_bullet(doc, item)

    # Implementation Plan
    add_heading(doc, "9. Proposed Implementation Plan")
    phases = [
        (
            "Phase 1 — Core Application (2–3 weeks)",
            "Login with token validation, in-memory session, bulk redirect engine, manual and CSV input, results panel.",
        ),
        (
            "Phase 2 — Security Hardening (1 week)",
            "IP display on login, improved error messaging for IP-restricted tokens, session cleanup on exit.",
        ),
        (
            "Phase 3 — Testing & Deployment (1 week)",
            "End-to-end testing across macOS and Windows, documentation, and internal rollout.",
        ),
    ]
    for title, desc in phases:
        p = doc.add_paragraph()
        run = p.add_run(title)
        run.bold = True
        doc.add_paragraph(desc)

    # Requirements
    add_heading(doc, "10. Requirements & Dependencies")
    reqs = [
        "Flutter SDK and build toolchain (Xcode on macOS, Visual Studio on Windows).",
        "Cloudflare API tokens with appropriate zone permissions.",
        "Workstations running macOS or Windows.",
        "Optional: IP allowlist configuration on Cloudflare tokens for enhanced security.",
    ]
    for item in reqs:
        add_bullet(doc, item)

    # Conclusion
    add_heading(doc, "11. Conclusion & Recommendation")
    doc.add_paragraph(
        "Cloudflare Bulk 301 addresses a clear operational need: fast, consistent, and secure "
        "bulk 301 redirect management across Cloudflare zones. By combining desktop-only "
        "deployment, token-based authentication with IP restrictions, and in-memory credential "
        "handling, the proposed application minimizes security risk while delivering measurable "
        "time savings."
    )
    doc.add_paragraph(
        "Approval to proceed with development is requested. Upon completion, the tool can be "
        "deployed internally to support domain migration, consolidation, and portfolio "
        "management initiatives."
    )

    doc.add_paragraph()
    closing = doc.add_paragraph()
    closing.alignment = WD_ALIGN_PARAGRAPH.LEFT
    add_horizontal_line(closing)
    footer = doc.add_paragraph()
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("— End of Proposal —")
    run.italic = True
    run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

    return doc


def main() -> None:
    doc = build_document()
    doc.save(OUTPUT_PATH)
    print(f"Created: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
