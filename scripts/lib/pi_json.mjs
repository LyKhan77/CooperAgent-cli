#!/usr/bin/env node

import fs from "node:fs";

function fail(message) {
  console.error(message);
  process.exit(2);
}

function readJson(path) {
  if (!path || path === "-") return {};
  if (!fs.existsSync(path)) return {};
  try {
    const raw = fs.readFileSync(path, "utf8").replace(/^\uFEFF/, "");
    return raw.trim() ? JSON.parse(raw) : {};
  } catch {
    fail(`JSON pi tidak valid: ${path}`);
  }
}

function object(value, label) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    fail(`Struktur JSON pi tidak valid: ${label} harus berupa objek`);
  }
  return value;
}

function template(path) {
  return object(readJson(path), path);
}

function mergeModels(existingPath, templatePath) {
  const root = object(readJson(existingPath), existingPath || "models.json");
  const tpl = template(templatePath);
  const providers = root.providers === undefined ? {} : object(root.providers, "providers");
  const tplProvider = object(tpl.providers?.cooperagent, "providers.cooperagent template");
  const oldProvider = providers.cooperagent === undefined
    ? {}
    : object(providers.cooperagent, "providers.cooperagent");
  const desired = Array.isArray(tplProvider.models) && tplProvider.models.length > 0
    ? object(tplProvider.models[0], "cooperagent model template")
    : fail("Template models pi tidak memuat model");

  const oldModels = oldProvider.models === undefined
    ? []
    : Array.isArray(oldProvider.models)
      ? oldProvider.models
      : fail("Struktur JSON pi tidak valid: cooperagent.models harus berupa array");
  const oldManaged = oldModels.find((model) =>
    model && typeof model === "object" &&
    (model.id === desired.id || String(model.name ?? "").startsWith("CooperAgent")));
  const preservedModels = oldModels.filter((model) =>
    !(model && typeof model === "object" &&
      (model.id === desired.id || String(model.name ?? "").startsWith("CooperAgent"))));

  const provider = {
    ...oldProvider,
    ...tplProvider,
    models: [{ ...(oldManaged ?? {}), ...desired }, ...preservedModels],
  };
  root.providers = { ...providers, cooperagent: provider };
  return root;
}

function mergeSettings(existingPath, templatePath) {
  const root = object(readJson(existingPath), existingPath || "settings.json");
  const tpl = template(templatePath);

  if (root.defaultProvider === undefined || root.defaultProvider === "") {
    root.defaultProvider = tpl.defaultProvider;
  }
  if (root.defaultModel === undefined || root.defaultModel === "") {
    root.defaultModel = tpl.defaultModel;
  }
  if (root.defaultProvider === "cooperagent") {
    root.defaultModel = tpl.defaultModel;
  }

  const oldCompaction = root.compaction === undefined
    ? {}
    : object(root.compaction, "compaction");
  const tplCompaction = object(tpl.compaction, "compaction template");
  root.compaction = { ...oldCompaction, ...tplCompaction };

  const tplSkills = Array.isArray(tpl.skills) ? tpl.skills : [];
  if (root.skills === undefined) {
    root.skills = tplSkills;
  } else if (Array.isArray(root.skills)) {
    root.skills = [...new Set([...root.skills, ...tplSkills])];
  } else {
    fail("Struktur JSON pi tidak valid: skills harus berupa array");
  }
  return root;
}

function getValue(kind, path, field) {
  const root = object(readJson(path), path);
  if (kind === "models") {
    const provider = root.providers?.cooperagent;
    if (!provider || typeof provider !== "object" || Array.isArray(provider)) return;
    if (field === "present") {
      process.stdout.write("yes\n");
    } else if (field === "gateway") {
      process.stdout.write(`${provider.baseUrl ?? ""}\n`);
    } else if (field === "apiKey") {
      process.stdout.write(`${provider.apiKey ?? ""}\n`);
    }
    return;
  }
  if (kind === "settings") {
    const compaction = root.compaction;
    if (field === "compactionEnabled") {
      process.stdout.write(`${compaction?.enabled === true ? "true" : "false"}\n`);
    } else if (field === "reserveTokens") {
      process.stdout.write(`${compaction?.reserveTokens ?? ""}\n`);
    }
  }
}

const [command, arg1, arg2, arg3] = process.argv.slice(2);
try {
  let result;
  if (command === "merge-models") {
    result = mergeModels(arg1, arg2);
  } else if (command === "merge-settings") {
    result = mergeSettings(arg1, arg2);
  } else if (command === "get") {
    getValue(arg1, arg2, arg3);
    process.exit(0);
  } else {
    fail("Perintah pi_json tidak dikenal");
  }
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
