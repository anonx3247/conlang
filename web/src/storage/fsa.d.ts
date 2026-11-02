// File System Access API, not yet in TypeScript's DOM library.
interface FilePickerOptions {
  suggestedName?: string;
  types?: { description?: string; accept: Record<string, string[]> }[];
}
interface Window {
  showSaveFilePicker(options?: FilePickerOptions): Promise<FileSystemFileHandle>;
  showOpenFilePicker(options?: FilePickerOptions): Promise<FileSystemFileHandle[]>;
}
