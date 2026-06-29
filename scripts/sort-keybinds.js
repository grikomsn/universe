#!/usr/bin/env node

const fs = require("node:fs");
const { globSync } = fs;
const checkOnly = process.argv.includes("--check");
let hasChanges = false;

const paths = globSync("**/keybindings.json", {
  cwd: process.cwd(),
  exclude: (name) => name === "node_modules",
});

function sortKeybindings(jsonPath) {
  const jsonContent = fs.readFileSync(jsonPath, "utf8");

  const parsedContent = JSON.parse(jsonContent);

  // Normalize keybindings by reordering modifiers to: shift, ctrl, alt, cmd
  var normalizedKeybindings = parsedContent.map((binding) => {
    if (!binding.key) return binding;

    // Handle chord keybindings (e.g., "cmd+k cmd+r")
    const chordParts = binding.key.split(" ");

    const normalizeKeyPart = (keyPart) => {
      const keyParts = keyPart.split("+");
      const modifiers = [];
      let baseKey = "";

      // Extract modifiers and base key
      for (const part of keyParts) {
        if (part === "shift") modifiers.push("shift");
        else if (part === "ctrl") modifiers.push("ctrl");
        else if (part === "alt") modifiers.push("alt");
        else if (part === "cmd") modifiers.push("cmd");
        else if (part === "meta") modifiers.push("meta");
        else baseKey = part;
      }

      // Sort modifiers in correct order: shift, ctrl, alt, cmd
      const orderedModifiers = [];
      if (modifiers.includes("shift")) orderedModifiers.push("shift");
      if (modifiers.includes("ctrl")) orderedModifiers.push("ctrl");
      if (modifiers.includes("alt")) orderedModifiers.push("alt");
      if (modifiers.includes("cmd")) orderedModifiers.push("cmd");
      if (modifiers.includes("meta")) orderedModifiers.push("meta");

      // Rebuild key string
      return orderedModifiers.length > 0
        ? `${orderedModifiers.join("+")}+${baseKey}`
        : baseKey;
    };

    // Normalize each part of the chord
    const normalizedChordParts = chordParts.map(normalizeKeyPart);
    const normalizedKey = normalizedChordParts.join(" ");

    return {
      ...binding,
      key: normalizedKey,
    };
  });

  normalizedKeybindings.sort((a, b) => {
    return a.key.localeCompare(b.key);
  });

  const trailingNewline = jsonContent.endsWith("\n") ? "\n" : "";
  const sortedContent =
    JSON.stringify(normalizedKeybindings, null, 2) + trailingNewline;

  if (sortedContent !== jsonContent) {
    hasChanges = true;
    if (checkOnly) {
      console.error(`${jsonPath} is not sorted`);
    } else {
      fs.writeFileSync(jsonPath, sortedContent, "utf8");
    }
  }
}

for (const jsonPath of paths) {
  sortKeybindings(jsonPath);
}

if (checkOnly) {
  if (hasChanges) process.exit(1);
  console.log("Keybindings are sorted.");
} else {
  console.log("Keybindings sorted and saved! 🎉");
}
