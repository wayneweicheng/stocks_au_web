"use client";

interface MarkdownRendererProps {
  content: string;
}

export default function MarkdownRenderer({ content }: MarkdownRendererProps) {
  const parseMarkdown = (text: string) => {
    let html = text;

    // Numbered section headers (e.g., "1. Executive Summary", "1.1 The Investment Thesis", "10. Conclusion")
    // Match patterns like "1. Title", "1.1 Title", "10.2 Title" at the start of a line
    html = html.replace(/^(\d+)\. ([A-Z][^\n]+)$/gm, '<h2 class="text-lg font-bold mt-8 mb-4 text-slate-900 border-b border-slate-200 pb-2">$1. $2</h2>');
    html = html.replace(/^(\d+\.\d+) ([A-Z][^\n]+)$/gm, '<h3 class="text-base font-semibold mt-6 mb-3 text-slate-800">$1 $2</h3>');

    // Standard markdown headers (must be processed before other formatting)
    html = html.replace(/^#### (.*$)/gim, '<h4 class="text-sm font-semibold mt-4 mb-2 text-slate-800">$1</h4>');
    html = html.replace(/^### (.*$)/gim, '<h3 class="text-base font-semibold mt-6 mb-3 text-slate-800">$1</h3>');
    html = html.replace(/^## (.*$)/gim, '<h2 class="text-lg font-bold mt-8 mb-4 text-slate-900 border-b border-slate-200 pb-2">$1</h2>');
    html = html.replace(/^# (.*$)/gim, '<h1 class="text-xl font-bold mt-8 mb-4 text-slate-900">$1</h1>');

    // Tables - parse markdown tables into HTML tables (pipe-delimited with separator)
    html = html.replace(/((?:^\|.+\|$\n?)+)/gm, (match) => {
      const lines = match.trim().split('\n').filter(line => line.trim());
      if (lines.length < 2) return match;

      // Check if second line is a separator (contains dashes)
      const separatorLine = lines[1];
      if (!/^\|[\s\-:|]+\|$/.test(separatorLine)) return match;

      // Parse header row
      const headerCells = lines[0]
        .split('|')
        .filter((cell, i, arr) => i > 0 && i < arr.length - 1)
        .map(cell => `<th class="px-4 py-3 text-left font-semibold text-slate-700 bg-slate-100 border border-slate-200">${cell.trim()}</th>`)
        .join('');

      // Parse data rows (skip header and separator)
      const dataRows = lines.slice(2).map(line => {
        const cells = line
          .split('|')
          .filter((cell, i, arr) => i > 0 && i < arr.length - 1)
          .map(cell => `<td class="px-4 py-3 border border-slate-200">${cell.trim()}</td>`)
          .join('');
        return `<tr class="hover:bg-slate-50">${cells}</tr>`;
      }).join('');

      return `<div class="overflow-x-auto my-6"><table class="min-w-full text-sm border-collapse border border-slate-200 rounded-lg"><thead><tr>${headerCells}</tr></thead><tbody>${dataRows}</tbody></table></div>`;
    });

    // Plain text tables (consecutive lines that look like key-value pairs)
    // Pattern: lines with content followed by lines with values, repeating
    // Detect blocks that look like plain text tables (label on one line, value on next)
    html = html.replace(/((?:^[A-Z][A-Za-z\s\(\)]+\n(?:[A-Z$~][\w\s$~%.,\-()]+|[\d]+)\n?)+)/gm, (match) => {
      const lines = match.trim().split('\n').filter(line => line.trim());
      if (lines.length < 4 || lines.length % 2 !== 0) return match; // Need even number of lines (label + value pairs)

      // Check if this looks like a key-value table (alternating labels and values)
      let isTable = true;
      const rows: Array<{label: string, value: string}> = [];
      for (let i = 0; i < lines.length; i += 2) {
        const label = lines[i].trim();
        const value = lines[i + 1]?.trim() || '';
        // Labels typically start with capital letter and contain mostly letters
        if (!/^[A-Z]/.test(label)) {
          isTable = false;
          break;
        }
        rows.push({ label, value });
      }

      if (!isTable || rows.length < 2) return match;

      const tableRows = rows.map(row =>
        `<tr class="hover:bg-slate-50"><td class="px-4 py-2 border border-slate-200 font-medium text-slate-700 bg-slate-50 w-1/3">${row.label}</td><td class="px-4 py-2 border border-slate-200">${row.value}</td></tr>`
      ).join('');

      return `<div class="overflow-x-auto my-6"><table class="min-w-full text-sm border-collapse border border-slate-200 rounded-lg"><tbody>${tableRows}</tbody></table></div>`;
    });

    // Convert consecutive list items into proper <ul> blocks
    html = html.replace(/((?:^[\*\-] .+$\n?)+)/gm, (match) => {
      const items = match
        .trim()
        .split('\n')
        .map(line => {
          const itemContent = line.replace(/^[\*\-] /, '');
          return `<li class="ml-4">${itemContent}</li>`;
        })
        .join('');
      return `<ul class="list-disc ml-4 space-y-1 my-3">${items}</ul>`;
    });

    // Numbered lists (but not section headers - those start with capital letter after the number)
    // Only match numbered items that are actual list items
    html = html.replace(/((?:^\d+\. (?![A-Z][a-z]+\s+[A-Z]).+$\n?)+)/gm, (match) => {
      // Skip if this looks like section headers
      if (/^\d+\. [A-Z][a-z]+\s+[A-Z]/.test(match)) return match;

      const items = match
        .trim()
        .split('\n')
        .map(line => {
          const itemContent = line.replace(/^\d+\. /, '');
          return `<li class="ml-4">${itemContent}</li>`;
        })
        .join('');
      return `<ol class="list-decimal ml-4 space-y-1 my-3">${items}</ol>`;
    });

    // Bold (must come before italic to handle ** correctly)
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong class="font-semibold text-slate-900">$1</strong>');

    // Italic
    html = html.replace(/\*(.*?)\*/g, '<em class="italic">$1</em>');

    // Code blocks (backticks)
    html = html.replace(/`([^`]+)`/g, '<code class="bg-slate-100 px-1.5 py-0.5 rounded text-sm font-mono text-slate-800">$1</code>');

    // Horizontal rules
    html = html.replace(/^---$/gm, '<hr class="my-8 border-slate-300" />');

    // Sub-section labels (lines ending with colon that introduce content)
    html = html.replace(/^([A-Z][A-Za-z\s\-]+):$/gm, '<h4 class="text-sm font-semibold mt-5 mb-2 text-slate-700">$1:</h4>');

    // Line breaks - convert double newlines to paragraphs
    html = html.replace(/\n\n+/g, '</p><p class="mb-3">');
    html = '<p class="mb-3">' + html + '</p>';

    // Clean up empty paragraphs
    html = html.replace(/<p class="mb-3"><\/p>/g, '');

    // Clean up paragraphs that only contain whitespace
    html = html.replace(/<p class="mb-3">\s*<\/p>/g, '');

    return html;
  };

  return (
    <div
      className="text-sm text-slate-700 leading-relaxed prose-slate max-w-none"
      dangerouslySetInnerHTML={{ __html: parseMarkdown(content) }}
    />
  );
}
