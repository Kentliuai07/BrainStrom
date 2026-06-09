# Build prompt for Claude.ai (English) · BrainStrom

> Copy everything between the "===" lines into Claude.ai (web).

===

ROLE: You are a senior product designer + front-end engineer.

GOAL: Build an interactive **mobile (iOS) front-end prototype** for an app called **BrainStrom** — a "vibe coding" notebook. Then present it in **several distinct visual styles**, **describe each style's design aesthetic in English**, and give me **live controls** to switch and fine-tune the look.

## DELIVERY FORMAT (important)
- Output each visual style as its **own self-contained, single-file artifact** (HTML + Tailwind via CDN + vanilla JS, or single-file React). Each must run by just opening it — no build step.
- Make every artifact **one-click copyable** — put each in its own code block / artifact with the full file.
- Mobile size, inside an **iPhone frame** (status bar, dynamic island, home indicator).
- Use a **line icon set (Lucide), NOT emoji**. Consistent icon language.
- Use placeholder/sample data. Sample project: **"PDF Q&A Assistant"**.
- CJK text should look like **PingFang**; Latin like **Inter**.

## PRODUCT — what it is
A note app for "vibe coders" (often non-engineers / creatives who don't know dev jargon). **Each note = one "system theme" to be built.** The user keeps dumping raw thoughts; AI restructures them into a fixed format.

## CORE FEATURES
**1) Two modes on the SAME note**, switched by a top iOS segmented control (must actually toggle):
- **Free Capture** — write freely like Apple Notes, no formatting needed, continuous input.
- **AI Structured** — a button on the right restructures the whole note into ONE fixed unified format (identical for every note), shown as clean cards:
  - (a) **System name**
  - (b) **Tech stack**
  - (c) **GitHub references** (ready-to-use open source)
  - (d) **Build steps**
  - (e) **End-user instructions**
  - (f) **HTML-style slot** (a space to drop / preview HTML snippets)
  - (g) **Dev focus** (split into UI/UX, Frontend, Backend)

  Product logic: the user has a no-formatting, always-on input version; AI converts it into the formatted version. Both coexist and are switchable.

**2) Bottom-left module toolbar** — a module button; tapping opens a list of **named** modules the user can insert (in MVP every module HAS a name). Modules (vibe-coding specific):
Dev Logic (can generate a flow / mind map) · Platform Tools · Reference Videos · GitHub Open Source · Prompt Library · AI Analysis.

## VISUAL BASELINE
Apple Notes feel — warm paper, clean typography, centered date, big title, comfortable line-height, frosted toolbar.

## KEY ASK — MULTIPLE STYLES + LIVE CONTROL
**A) Produce the SAME screen in at least 4 distinct visual styles.** For EACH style, first write a short **English paragraph describing its aesthetic** (mood, color, typography, shape language, references), then provide the code. Suggested styles (refine as you see fit):
1. **Warm Paper** — Apple Notes baseline; cream, soft, editorial calm.
2. **Clean Minimal** — Linear / Notion vibe; cool neutral grays, crisp hairlines, high clarity.
3. **Soft Clay** — claymorphism; plump rounded shapes, pastel palette, tactile shadows.
4. **Dark Glass** — dark mode; glassmorphism / vibrancy, neon accent, depth.
5. **Editorial Bold** — big expressive type, strong grid, magazine feel.

**B) UI/UX MUST BE CONTROLLABLE / MANIPULABLE.** Include a **floating control panel** in the prototype that lets me, in real time:
- switch between the styles above,
- toggle light / dark,
- change accent color,
- change corner radius (sharp ↔ round),
- change density (compact ↔ comfortable),
- change font pairing.

Implement the design with **CSS variables / design tokens** so these controls actually re-skin the whole UI live.

## QUALITY BAR
Rounded corners, generous whitespace, soft shadows, line icons, genuine iOS polish. It must feel premium, not like a rough wireframe.

## OUTPUT ORDER
1. A short English **design-system overview** (the tokens you expose).
2. For each style: **English aesthetic description** + a **one-click-copyable** self-contained file.
3. A final **combined build** that includes the **live control panel** to switch styles and tweak tokens.

## SAMPLE CONTENT ("PDF Q&A Assistant")
- Free-capture raw text (paraphrase): "Want a tool where you upload a PDF and just ask it questions instead of reading the whole thing. Flow: upload → chunk → embed into a vector store → on a question, retrieve the most relevant chunks → send them with the question to Claude. Backend: Supabase (pgvector). Frontend chat: Vercel AI SDK. Prompt must say 'answer only from retrieved content; if not found, say you don't know; never make things up.' Watch that RAG YouTube tutorial and the langchain example on GitHub."
- AI-structured (a)–(g): (a) PDF Q&A Assistant; (b) Supabase + pgvector, Vercel AI SDK, Claude API; (c) langchain-ai/langchain (RAG example), supabase/supabase; (d) ① upload & chunk ② embed & store ③ question → retrieve → Claude answers; (e) upload PDF → ask in the chat box → get an answer with sources; (f) placeholder for a chat-bubble + answer-card HTML snippet; (g) UI/UX: conversational, cite sources | Frontend: streaming output | Backend: retrieval accuracy + graceful "not found".

===
