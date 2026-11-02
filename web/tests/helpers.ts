import { applyCommand } from '../src/core/commands';
import { engineFor } from '../src/core/engine';
import { emptyProject, type ProjectDoc } from '../src/core/types';

export function project(setup: (d: ProjectDoc) => void): ProjectDoc {
  const doc = emptyProject('Test', '2026-01-01T00:00:00.000Z');
  setup(doc);
  return doc;
}

export function run<T>(doc: ProjectDoc, cmd: (d: ProjectDoc) => T) {
  return applyCommand(doc, cmd).doc;
}

export const engine = engineFor;
