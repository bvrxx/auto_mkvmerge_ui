// src/routes/api/run-script/+server.ts
import type { RequestHandler } from './$types';
import { spawn } from 'child_process';

export const POST: RequestHandler = async ({ request }) => {
  const data = await request.json() as { folder1: string; folder2: string };

  // Example script command (replace with your merge script)
  const command = 'bash'; // could be 'python', 'node', or a shell script
  const args = ['./merge-script.sh', data.folder1, data.folder2];

  return new Response(
    new ReadableStream({
      start(controller) {
        const proc = spawn(command, args);

        proc.stdout.on('data', (chunk: Buffer) => {
          controller.enqueue(chunk);
        });

        proc.stderr.on('data', (chunk: Buffer) => {
          controller.enqueue(chunk);
        });

        proc.on('close', () => {
          controller.close();
        });

        proc.on('error', (err: Error) => {
          controller.enqueue(new TextEncoder().encode(`Error: ${err.message}\n`));
          controller.close();
        });
      }
    }),
    { headers: { 'Content-Type': 'text/plain' } }
  );
};