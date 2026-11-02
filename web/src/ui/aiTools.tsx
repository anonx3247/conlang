import { canUseFiles, useApp } from '../storage/store';
import { Dialog, FilledButton, TextButton } from './common';

/** Explains how an MCP client connects to the project file on this computer. */
export function AiToolsDialog({ onClose }: { onClose: () => void }) {
  const { registry, projectId } = useApp();
  const entry = registry.find((e) => e.id === projectId);
  const file = entry?.fileName ?? 'MyLanguage.conlang.json';
  const config = JSON.stringify(
    {
      mcpServers: {
        'conlang-workbench': {
          command: 'node',
          args: ['/absolute/path/to/conlang-mcp.mjs', '--project', `/absolute/path/to/${file}`],
        },
      },
    },
    null,
    2,
  );
  return (
    <Dialog
      title="AI Tools (MCP)"
      onClose={onClose}
      actions={
        <>
          <a className="btn text" href="/conlang-mcp.mjs" download>Download MCP server</a>
          <TextButton onClick={() => void navigator.clipboard.writeText(config)}>Copy config</TextButton>
          <FilledButton onClick={onClose}>Done</FilledButton>
        </>
      }
    >
      <div>
        AI clients such as Claude Desktop or Claude Code connect to a small program on your own computer that reads and edits your
        project file. This web page never talks to it directly and nothing is uploaded: the file on disk is the only link.
      </div>
      <ol style={{ margin: 0, paddingLeft: 18 }}>
        <li>Download the MCP server (requires Node.js).</li>
        <li>Add the config below to your AI client, filling in both paths.</li>
        <li>Changes the AI makes show up here within a couple of seconds.</li>
      </ol>
      <pre className="code">{config}</pre>
      {!canUseFiles && (
        <div className="banner error">
          This browser can't keep a live link to a file. Use Chrome or Edge for two-way sync, or use File → Download a Copy and point the server at the downloaded file.
        </div>
      )}
      {canUseFiles && entry && !entry.fileName && (
        <div className="banner">This project is only saved in the browser. Use File → Save As to give it a file the MCP server can open.</div>
      )}
    </Dialog>
  );
}
