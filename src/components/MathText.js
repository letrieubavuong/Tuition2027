"use client";

import React, { useMemo } from "react";
import katex from "katex";

/**
 * MathText component renders LaTeX math enclosed in $...$, $$...$$, \(...\), or \[...\]
 * gracefully falling back to raw text if KaTeX fails or text has no math.
 */
export default function MathText({ text = "", style, className }) {
  const renderedHtml = useMemo(() => {
    if (!text || typeof text !== "string") return "";

    try {
      // Regex to match math delimiters: $$...$$, \[...\], $...$, \(...\)
      const mathRegex = /(\$\$[\s\S]+?\$\$|\\\[[\s\S]+?\\\]|\$[\s\S]+?\$|\\\([\s\S]+?\\\))/g;

      const parts = text.split(mathRegex);

      return parts
        .map((part) => {
          if (!part) return "";

          // Block Math $$...$$ or \[...\]
          if (part.startsWith("$$") && part.endsWith("$$")) {
            const math = part.slice(2, -2).trim();
            return katex.renderToString(math, { displayMode: true, throwOnError: false });
          }
          if (part.startsWith("\\[") && part.endsWith("\\]")) {
            const math = part.slice(2, -2).trim();
            return katex.renderToString(math, { displayMode: true, throwOnError: false });
          }

          // Inline Math $...$ or \(...\)
          if (part.startsWith("$") && part.endsWith("$") && part.length > 1) {
            const math = part.slice(1, -1).trim();
            return katex.renderToString(math, { displayMode: false, throwOnError: false });
          }
          if (part.startsWith("\\(") && part.endsWith("\\)")) {
            const math = part.slice(2, -2).trim();
            return katex.renderToString(math, { displayMode: false, throwOnError: false });
          }

          // Escaped html characters in normal text
          return part
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\n/g, "<br/>");
        })
        .join("");
    } catch (e) {
      console.error("MathText KaTeX error:", e);
      return text;
    }
  }, [text]);

  return (
    <span
      className={className}
      style={style}
      dangerouslySetInnerHTML={{ __html: renderedHtml }}
    />
  );
}
