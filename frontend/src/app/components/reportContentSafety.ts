import sanitizeHtml from "sanitize-html";

const reportTags = [...sanitizeHtml.defaults.allowedTags, "img"];
const safeLinksAndImages = {
  a: ["href", "name", "title", "target", "rel"],
  img: ["src", "alt", "title", "width", "height"],
};
const safeLinkTargets: sanitizeHtml.IOptions["transformTags"] = {
  a: (tagName, attributes) => ({ tagName, attribs: {
    ...attributes,
    ...(attributes.target === "_blank" ? { rel: "noopener noreferrer" } : {}),
  } }),
};

/** Remove report-supplied scripts, handlers, styles and CSS classes before Markdown formatting. */
export function sanitizeMarkdownSource(content: string): string {
  return sanitizeHtml(content, { allowedTags: reportTags, allowedAttributes: safeLinksAndImages, transformTags: safeLinkTargets });
}

/** Preserve only formatter-generated classes after Markdown has been converted to HTML. */
export function sanitizeRenderedMarkdown(html: string): string {
  return sanitizeHtml(html, {
    allowedTags: reportTags,
    allowedAttributes: { ...safeLinksAndImages, "*": ["class"] },
    transformTags: safeLinkTargets,
  });
}

const escapeAttribute = (value: string) => value.replace(/[&<>"']/g, (char) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
})[char] || char);

/** Full-screen HTML report viewer: the blob's own document contains no report HTML or scripts.
 * Its iframe has an opaque origin and cannot access the site's localStorage or navigate the parent.
 * Permit inline chart scripts, but not forms, popups, modals, top navigation or same-origin access.
 */
export function sandboxedReportDocument(content: string): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Report preview</title><style>html,body{margin:0;height:100%;background:#fff}iframe{display:block;border:0;width:100%;height:100%}</style></head><body><iframe title="Report" sandbox="allow-scripts" srcdoc="${escapeAttribute(content)}"></iframe></body></html>`;
}
