import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import ts from "typescript";
const require = createRequire(import.meta.url);
export function loadTypeScriptModule(filename, mocks = {}, cache = new Map()) {
  filename = path.resolve(filename);
  if (cache.has(filename)) return cache.get(filename).exports;
  const compiled = ts.transpileModule(fs.readFileSync(filename, "utf8"), {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      jsx: ts.JsxEmit.ReactJSX
    }
  }).outputText;
  const result = { exports: {} };
  cache.set(filename, result);
  const localRequire = (name) => {
    if (Object.hasOwn(mocks, name)) return mocks[name];
    if (name.startsWith(".") || name.startsWith("@/")) {
      const base = name.startsWith("@/")
        ? path.resolve("src", name.slice(2))
        : path.resolve(path.dirname(filename), name);
      const candidate = [base, `${base}.ts`, `${base}.tsx`].find(
        (file) => fs.existsSync(file) && fs.statSync(file).isFile()
      );
      if (!candidate)
        throw new Error(`Cannot resolve ${name} from ${filename}`);
      return loadTypeScriptModule(candidate, mocks, cache);
    }
    return require(name);
  };
  new Function("exports", "module", "require", compiled)(
    result.exports,
    result,
    localRequire
  );
  return result.exports;
}
