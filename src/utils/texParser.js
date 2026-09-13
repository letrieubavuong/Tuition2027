/**
 * Parser for Vietnam ex_test package LaTeX exam files.
 * Extracts questions (\begin{ex}...\end{ex}) supporting:
 *  - 4-option multiple choice (\choice {..} {\True ..} {..} {..})
 *  - True/False multi-item (\choiceTF {\True ..} {..} {\True ..} {..})
 *  - Short answer (\shortans{..})
 *  - Solutions (\loigiai{..} or \begin{loigiai}...\end{loigiai})
 */

function cleanBracesContent(str) {
  if (!str) return "";
  let s = str.trim();
  if (s.startsWith("{") && s.endsWith("}")) {
    s = s.slice(1, -1).trim();
  }
  return s;
}

// Helper to extract nested braced group {...}
function extractBracedGroups(text) {
  const groups = [];
  let depth = 0;
  let currentGroup = "";
  let inGroup = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === "{") {
      if (depth === 0) {
        inGroup = true;
        currentGroup = "";
      } else {
        currentGroup += char;
      }
      depth++;
    } else if (char === "}") {
      depth--;
      if (depth === 0) {
        inGroup = false;
        groups.push(currentGroup.trim());
        currentGroup = "";
      } else {
        currentGroup += char;
      }
    } else if (inGroup) {
      currentGroup += char;
    }
  }

  return groups;
}

export function parseExTest(texContent) {
  if (!texContent || typeof texContent !== "string") return [];

  // Remove TeX comments (% ...) except escaped \%
  const cleanedTex = texContent
    .replace(/(^|[^\\])%[^\n]*/g, "$1")
    .replace(/\r\n/g, "\n");

  // Regex to match \begin{ex}... \end{ex} or \begin{ex}[...]\end{ex}
  const exRegex = /\\begin\{ex\}(?:\[[\s\S]*?\])?([\s\S]*?)\\end\{ex\}/g;
  const questions = [];

  let match;
  let qCount = 0;

  while ((match = exRegex.exec(cleanedTex)) !== null) {
    qCount++;
    const exBody = match[1].trim();

    // 1. Extract Solution (\loigiai{...} or \begin{loigiai}...\end{loigiai})
    let loiGiai = "";
    let mainBody = exBody;

    const loigiaiBlockRegex = /\\begin\{loigiai\}([\s\S]*?)\\end\{loigiai\}/;
    const loigiaiCmdRegex = /\\loigiai\{([\s\S]*?)\}$/;

    if (loigiaiBlockRegex.test(mainBody)) {
      const lgMatch = mainBody.match(loigiaiBlockRegex);
      loiGiai = lgMatch[1].trim();
      mainBody = mainBody.replace(loigiaiBlockRegex, "").trim();
    } else {
      // Find \loigiai at the end of exBody
      const lgIndex = mainBody.lastIndexOf("\\loigiai");
      if (lgIndex !== -1) {
        const afterLg = mainBody.slice(lgIndex + 8).trim();
        loiGiai = cleanBracesContent(afterLg);
        mainBody = mainBody.slice(0, lgIndex).trim();
      }
    }

    // 2. Check Question Type & Parse Options
    let loai_cau_hoi = "TRAC_NGHIEM_4_DAP_AN";
    let noi_dung = mainBody;
    let phuong_an = [];
    let y_hoi = [];
    let dap_an_dung = "A";

    // --- CHECK FOR \choiceTF (True/False) ---
    if (mainBody.includes("\\choiceTF")) {
      loai_cau_hoi = "TRAC_NGHIEM_DUNG_SAI";
      const parts = mainBody.split("\\choiceTF");
      noi_dung = parts[0].trim();

      const optionsText = parts[1] ? parts[1].trim() : "";
      const groups = extractBracedGroups(optionsText);

      const labels = ["a", "b", "c", "d"];
      const correctObj = {};

      y_hoi = groups.slice(0, 4).map((grp, idx) => {
        const isTrue = grp.includes("\\True");
        const cleanItem = grp.replace(/\\True/g, "").trim();
        correctObj[idx] = isTrue ? "DUNG" : "SAI";
        const label = labels[idx] || `${idx + 1}`;
        return cleanItem.startsWith(`${label})`) || cleanItem.startsWith(`${label}.`)
          ? cleanItem
          : `${label}) ${cleanItem}`;
      });

      // Fill remaining if less than 4
      while (y_hoi.length < 4) {
        const idx = y_hoi.length;
        const label = labels[idx];
        y_hoi.push(`${label}) Ý hỏi ${label}`);
        correctObj[idx] = "SAI";
      }

      dap_an_dung = correctObj;
    }
    // --- CHECK FOR \shortans (Short Answer) ---
    else if (mainBody.includes("\\shortans")) {
      loai_cau_hoi = "TRA_LOI_NGAN";
      const parts = mainBody.split("\\shortans");
      noi_dung = parts[0].trim();

      const ansText = parts[1] ? parts[1].trim() : "";
      const groups = extractBracedGroups(ansText);
      let rawAns = groups[0] || ansText;
      rawAns = rawAns.replace(/[\$\{\}]/g, "").trim();
      dap_an_dung = rawAns || "0";
    }
    // --- CHECK FOR \choice (4-Choice Multiple Choice) ---
    else if (mainBody.includes("\\choice")) {
      loai_cau_hoi = "TRAC_NGHIEM_4_DAP_AN";
      const parts = mainBody.split("\\choice");
      noi_dung = parts[0].trim();

      const optionsText = parts[1] ? parts[1].trim() : "";
      const groups = extractBracedGroups(optionsText);

      const optionLetters = ["A", "B", "C", "D"];
      let foundCorrect = "A";

      phuong_an = groups.slice(0, 4).map((grp, idx) => {
        const isTrue = grp.includes("\\True");
        if (isTrue) {
          foundCorrect = optionLetters[idx];
        }
        const cleanOpt = grp.replace(/\\True/g, "").trim();
        const letter = optionLetters[idx] || `${idx + 1}`;

        return cleanOpt.startsWith(`${letter}.`) || cleanOpt.startsWith(`${letter})`)
          ? cleanOpt
          : `${letter}. ${cleanOpt}`;
      });

      // Fill remaining if less than 4
      while (phuong_an.length < 4) {
        const idx = phuong_an.length;
        const letter = optionLetters[idx];
        phuong_an.push(`${letter}. Phương án ${letter}`);
      }

      dap_an_dung = foundCorrect;
    } else {
      // Fallback: If no choice or shortans, default to short answer or single choice
      loai_cau_hoi = "TRA_LOI_NGAN";
      noi_dung = mainBody.trim();
      dap_an_dung = "1";
    }

    questions.push({
      id: `q_tex_${Date.now()}_${qCount}`,
      loai_cau_hoi,
      noi_dung,
      phuong_an,
      y_hoi,
      dap_an_dung,
      loi_giai: loiGiai || "Chưa có lời giải chi tiết.",
    });
  }

  return questions;
}
