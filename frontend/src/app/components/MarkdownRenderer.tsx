"use client";

interface MarkdownRendererProps {
  content: string;
}

export default function MarkdownRenderer({ content }: MarkdownRendererProps) {
  const parseMarkdown = (text: string) => {
    let html = text;

    // Headers (must be processed before other formatting to avoid conflicts)
    html = html.replace(/^### (.*$)/gim, '<h3 class="text-base font-semibold mt-4 mb-2 text-slate-800">$1</h3>');
    html = html.replace(/^## (.*$)/gim, '<h2 class="text-lg font-semibold mt-6 mb-3 text-slate-900">$1</h2>');
    html = html.replace(/^# (.*$)/gim, '<h1 class="text-xl font-bold mt-6 mb-4 text-slate-900">$1</h1>');

    // Convert consecutive list items into proper <ul> blocks
    // This regex finds groups of lines starting with "* " or "-"
    html = html.replace(/((?:^[\*\-] .+$\n?)+)/gm, (match) => {
      const items = match
        .trim()
        .split('\n')
        .map(line => {
          const content = line.replace(/^[\*\-] /, '');
          return `<li class="ml-4">${content}</li>`;
        })
        .join('');
      return `<ul class="list-disc ml-4 space-y-1 my-2">${items}</ul>`;
    });

    // Bold (must come before italic to handle ** correctly)
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong class="font-semibold text-slate-900">$1</strong>');

    // Italic
    html = html.replace(/\*(.*?)\*/g, '<em class="italic">$1</em>');

    // Code blocks (backticks)
    html = html.replace(/`([^`]+)`/g, '<code class="bg-slate-100 px-1 py-0.5 rounded text-sm font-mono">$1</code>');

    // Line breaks - convert double newlines to paragraphs
    html = html.replace(/\n\n+/g, '</p><p class="mb-2">');
    html = '<p class="mb-2">' + html + '</p>';

    // Clean up empty paragraphs
    html = html.replace(/<p class="mb-2"><\/p>/g, '');

    return html;
  };

  return (
    <div
      className="text-sm text-slate-700 leading-relaxed"
      dangerouslySetInnerHTML={{ __html: parseMarkdown(content) }}
    />
  );
}
