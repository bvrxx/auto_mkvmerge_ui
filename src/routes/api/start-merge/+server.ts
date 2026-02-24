// src/routes/api/start-merge/+server.ts
import type { RequestHandler } from './$types';
import { spawn } from 'child_process';
import stripAnsi from 'strip-ansi'; // npm install strip-ansi

// Keep reference to the current process so we can cancel it
let currentProcess: ReturnType<typeof spawn> | null = null;

export const POST: RequestHandler = async ({ request }) => {
  const data = await request.json() as { folder1: string; folder2: string };

  const command = 'bash'; // replace with your script command
  const args = ['./auto_mkvmerge.sh', data.folder1, data.folder2];

  return new Response(
    new ReadableStream({
      start(controller) {
        let closed = false; // track if controller is closed

        currentProcess = spawn(command, args);

        const safeEnqueue = (chunk: Buffer) => {
          if (!closed) {
            try {
              controller.enqueue(new TextEncoder().encode(stripAnsi(chunk.toString())));
            } catch (e) {
              // ignore enqueue errors if controller is already closed
            }
          }
        };

        currentProcess.stdout.on('data', safeEnqueue);
        currentProcess.stderr.on('data', safeEnqueue);

        currentProcess.on('close', () => {
          if (!closed) controller.close();
          closed = true;
          currentProcess = null;
        });

        currentProcess.on('error', (err: Error) => {
          if (!closed) controller.enqueue(new TextEncoder().encode(`Error: ${err.message}\n`));
          if (!closed) controller.close();
          closed = true;
          currentProcess = null;
        });
      },
      cancel() {
        // called if frontend cancels stream
        if (currentProcess) {
          currentProcess.kill('SIGTERM');
          currentProcess = null;
        }
      }
    }),
    { headers: { 'Content-Type': 'text/plain' } }
  );
};

// DELETE endpoint is optional, since cancel() is already handled
export const DELETE: RequestHandler = async () => {
  if (currentProcess) {
    currentProcess.kill('SIGTERM');
    currentProcess = null;
    return new Response('Process canceled', { status: 200 });
  }
  return new Response('No process running', { status: 400 });
};