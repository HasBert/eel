#!/usr/bin/env node
/**
 * Generic tokenization test runner for eel's Nix embedded-language grammar.
 *
 * Usage:
 *   node tokenize-eel.js <nix.embedded.tmLanguage.json> <fixture.nix> <expect.json>
 *
 * expect.json:
 * {
 *   "checks": [
 *     { "match": "echo", "hasAny": ["source.css"], "note": "inside embedded block is css" },
 *     { "afterMatch": "'';", "notHasAny": ["source.css"], "note": "after terminator is not css" }
 *   ]
 * }
 */
const fs = require("fs");
const path = require("path");
const vsctm = require("vscode-textmate");
const onig = require("vscode-oniguruma");

function die(msg) {
  console.error(msg);
  process.exit(2);
}

function readUtf8(p) {
  return fs.readFileSync(p, "utf8");
}

function readJson(p) {
  return JSON.parse(readUtf8(p));
}

function uniq(arr) {
  return Array.from(new Set(arr));
}

function scopesContain(scopes, needle) {
  return scopes.some((s) => s === needle || s.includes(needle));
}

function assertHasAny(scopes, any, ctx) {
  const ok = any.some((x) => scopesContain(scopes, x));
  if (!ok) {
    throw new Error(`FAIL: ${ctx}\nExpected any of: ${JSON.stringify(any)}\nScopes sample: ${JSON.stringify(scopes.slice(0, 25))}`);
  }
}

function assertNotHasAny(scopes, any, ctx) {
  const bad = any.some((x) => scopesContain(scopes, x));
  if (bad) {
    throw new Error(`FAIL: ${ctx}\nExpected none of: ${JSON.stringify(any)}\nScopes sample: ${JSON.stringify(scopes.slice(0, 25))}`);
  }
}

function findLineContaining(lines, needle) {
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes(needle)) return i + 1; // 1-based
  }
  return null;
}

function nextNonEmptyLine(lines, line1) {
  for (let i = line1; i < lines.length; i++) {
    if (lines[i].trim() !== "") return i + 1; // 1-based
  }
  return null;
}

function maybeLoadTestGrammar(scope) {
  // Optional: provide minimal grammars for embedded scopes if the main grammar includes them.
  // File names like: tests/tokenizer/grammars/source.shell.tmLanguage.json
  const p = path.join(__dirname, "grammars", `${scope}.tmLanguage.json`);
  if (!fs.existsSync(p)) return null;
  const rawText = readUtf8(p);
  const rawObj = JSON.parse(rawText);

  // vscode-textmate requires raw grammar scopeName to match the requested scope
  rawObj.scopeName = scope;
  return vsctm.parseRawGrammar(JSON.stringify(rawObj), p);
}

(async () => {
  const grammarPath = process.argv[2];
  const fixturePath = process.argv[3];
  const expectPath = process.argv[4];

  if (!grammarPath || !fixturePath || !expectPath) {
    die("usage: tokenize-eel.js <path-to-nix.embedded.tmLanguage.json> <fixture.nix> <expect.json>");
  }

  // Load oniguruma WASM
  const wasmPath = require.resolve("vscode-oniguruma/release/onig.wasm");
  const wasmBin = fs.readFileSync(wasmPath).buffer;
  await onig.loadWASM(wasmBin);

  const onigLib = Promise.resolve({
    createOnigScanner: (sources) => new onig.OnigScanner(sources),
    createOnigString: (str) => new onig.OnigString(str),
  });

  const grammarJsonText = readUtf8(grammarPath);
  const grammarObj = JSON.parse(grammarJsonText);
  const scopeName = grammarObj.scopeName;
  if (!scopeName) die(`No scopeName in grammar: ${grammarPath}`);

  const registry = new vsctm.Registry({
    onigLib,
    loadGrammar: async (scope) => {
      if (scope === scopeName) return vsctm.parseRawGrammar(grammarJsonText, grammarPath);

      // Optional embedded grammars (only if needed)
      const maybe = maybeLoadTestGrammar(scope);
      if (maybe) return maybe;

      return null;
    },
  });

  const grammar = await registry.loadGrammar(scopeName);
  if (!grammar) die(`Failed to load grammar: ${scopeName}`);

  const fixture = readUtf8(fixturePath);
  const lines = fixture.split(/\r?\n/);

  let ruleStack = vsctm.INITIAL;
  const lineScopes = [];

  for (let i = 0; i < lines.length; i++) {
    const r = grammar.tokenizeLine(lines[i], ruleStack);
    ruleStack = r.ruleStack;

    const allScopes = [];
    for (const t of r.tokens) allScopes.push(...t.scopes);

    lineScopes.push({
      lineNo: i + 1,
      line: lines[i],
      scopes: uniq(allScopes),
    });
  }

  // Always dump
  console.log(`--- DUMP: ${fixturePath} ---`);
  for (const l of lineScopes) {
    console.log(`${String(l.lineNo).padStart(4, " ")} | ${l.line}`);
    console.log(`     scopes: ${JSON.stringify(l.scopes.slice(0, 25))}`);
  }
  console.log(`--- END DUMP: ${fixturePath} ---`);

  // Run checks (no early-return; collect all failures)
  const spec = readJson(expectPath);
  const checks = Array.isArray(spec.checks) ? spec.checks : null;
  if (!checks || checks.length === 0) die(`No checks[] in ${expectPath}`);

  const failures = [];

  for (let i = 0; i < checks.length; i++) {
    const c = checks[i];
    try {
      let target = null;

      if (typeof c.match === "string") target = findLineContaining(lines, c.match);
      if (target === null && typeof c.line === "number") target = c.line;

      if (target === null && typeof c.afterMatch === "string") {
        const found = findLineContaining(lines, c.afterMatch);
        if (found === null) throw new Error(`afterMatch not found: ${c.afterMatch}`);
        target = nextNonEmptyLine(lines, found);
        if (target === null) throw new Error(`no non-empty line after afterMatch: ${c.afterMatch}`);
      }

      if (target === null && typeof c.afterLine === "number") {
        target = nextNonEmptyLine(lines, c.afterLine);
        if (target === null) throw new Error(`no non-empty line after afterLine: ${c.afterLine}`);
      }

      if (target === null) throw new Error("could not resolve target line");

      const scopes = (lineScopes[target - 1]?.scopes) ?? [];
      const note = c.note ? ` (${c.note})` : "";
      const ctx = `${fixturePath}: check[${i}] -> line ${target}${note}`;

      if (c.hasAny) assertHasAny(scopes, c.hasAny, ctx);
      if (c.notHasAny) assertNotHasAny(scopes, c.notHasAny, ctx);
      if (!c.hasAny && !c.notHasAny) throw new Error("missing hasAny/notHasAny");
    } catch (e) {
      failures.push(`check[${i}]: ${String(e && e.message ? e.message : e)}`);
    }
  }

  if (failures.length) {
    console.error("FAILURES:");
    for (const f of failures) console.error(`- ${f}`);
    process.exit(1);
  }

  console.log("PASS");
  process.exit(0);
})().catch((e) => {
  console.error(e && e.stack ? e.stack : String(e));
  process.exit(1);
});
