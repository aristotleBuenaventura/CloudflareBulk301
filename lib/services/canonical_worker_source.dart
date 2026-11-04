/// Cloudflare Worker that injects / updates `<link rel="canonical">` on HTML.
///
/// Canonical URL map is supplied via the `CANONICAL_MAP_JSON` plain-text binding.
/// Exact URL keys are checked first; then `__host__:{hostname}` for domain-wide rules.
abstract final class CanonicalWorkerSource {
  static const scriptName = 'seo-canonical-inject';

  static const javascript = r'''
function normalizeKey(url) {
  try {
    const u = new URL(url);
    u.hash = "";
    let href = u.toString();
    if (href.endsWith("/") && u.pathname !== "/") {
      href = href.slice(0, -1);
    }
    return href;
  } catch (_) {
    return url;
  }
}

function candidates(url) {
  const keys = new Set([url]);
  try {
    const u = new URL(url);
    u.hash = "";
    keys.add(u.toString());
    if (u.pathname.endsWith("/") && u.pathname !== "/") {
      const trimmed = new URL(u.toString());
      trimmed.pathname = trimmed.pathname.slice(0, -1);
      keys.add(trimmed.toString());
    } else if (u.pathname !== "/") {
      const withSlash = new URL(u.toString());
      withSlash.pathname = withSlash.pathname + "/";
      keys.add(withSlash.toString());
    } else {
      keys.add(u.origin + "/");
      keys.add(u.origin);
    }
    keys.add(normalizeKey(url));
  } catch (_) {}
  return [...keys];
}

function hostFallbackKeys(hostname) {
  const host = (hostname || "").toLowerCase();
  const keys = [`__host__:${host}`];
  if (host.startsWith("www.")) {
    keys.push(`__host__:${host.slice(4)}`);
  } else if (host) {
    keys.push(`__host__:www.${host}`);
  }
  return keys;
}

function lookupCanonical(map, requestUrl) {
  for (const key of candidates(requestUrl)) {
    if (Object.prototype.hasOwnProperty.call(map, key)) {
      const value = map[key];
      if (value === "" || value == null) {
        return requestUrl;
      }
      return value;
    }
  }

  try {
    const host = new URL(requestUrl).hostname;
    for (const key of hostFallbackKeys(host)) {
      if (Object.prototype.hasOwnProperty.call(map, key)) {
        const value = map[key];
        if (value === "" || value == null) {
          return requestUrl;
        }
        return value;
      }
    }
  } catch (_) {}

  return null;
}

class CanonicalElementHandler {
  constructor(canonical) {
    this.canonical = canonical;
    this.found = false;
  }
  element(element) {
    element.setAttribute("href", this.canonical);
    this.found = true;
  }
}

class HeadHandler {
  constructor(linkHandler) {
    this.linkHandler = linkHandler;
  }
  element(element) {
    const linkHandler = this.linkHandler;
    element.onEndTag((end) => {
      if (!linkHandler.found) {
        end.before(
          `<link rel="canonical" href="${linkHandler.canonical}" />`,
          { html: true }
        );
      }
    });
  }
}

export default {
  async fetch(request, env) {
    const response = await fetch(request);
    const contentType = response.headers.get("content-type") || "";
    if (!contentType.includes("text/html")) {
      return response;
    }

    let map = {};
    try {
      if (env.CANONICAL_MAP_JSON) {
        map = JSON.parse(env.CANONICAL_MAP_JSON);
      }
    } catch (_) {}

    const canonical = lookupCanonical(map, request.url);
    if (!canonical) {
      return response;
    }

    const linkHandler = new CanonicalElementHandler(canonical);
    return new HTMLRewriter()
      .on('link[rel="canonical"]', linkHandler)
      .on("head", new HeadHandler(linkHandler))
      .transform(response);
  },
};
''';
}