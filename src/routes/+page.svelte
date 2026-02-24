<script lang="ts">
  let folderPath1 = '';
  let folderPath2 = '';
  let output = '';
  let running = false;

  let controller: ReadableStreamDefaultReader<Uint8Array> | null = null;

  async function startMerge() {
    output = '';
    running = true;

    const res = await fetch('/api/start-merge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ folder1: folderPath1, folder2: folderPath2 })
    });

    if (!res.body) return;

    const reader = res.body.getReader();
    controller = reader;
    const decoder = new TextDecoder();

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      output += decoder.decode(value, { stream: true });
    }

    running = false;
    controller = null;
  }

  async function cancelMerge() {
    running = false;
    if (controller) {
      // abort reading the stream
      controller.cancel();
      controller = null;
    }

    await fetch('/api/start-merge', { method: 'DELETE' });
    output += '\n--- Merge canceled by user ---\n';
  }
</script>

<div class="min-h-screen flex items-center justify-center bg-gray-100 p-4">
  <div class="bg-white shadow-lg rounded-lg p-8 w-full max-w-4xl flex flex-col gap-4">
    <h1 class="text-3xl font-bold text-gray-800 mb-4 text-center">Auto MKV Merge</h1>

    <!-- Input Folder -->
    <div class="flex flex-col gap-1">
      <label class="text-gray-600 font-medium">Input Folder</label>
      <input
        type="text"
        placeholder="/path/to/input"
        bind:value={folderPath1}
        class="w-full border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-transparent transition"
      />
    </div>

    <!-- Output Folder -->
    <div class="flex flex-col gap-1 mt-2">
      <label class="text-gray-600 font-medium">Output Folder</label>
      <input
        type="text"
        placeholder="/path/to/output"
        bind:value={folderPath2}
        class="w-full border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-transparent transition"
      />
    </div>

  <div class="flex gap-2">
    <button on:click={startMerge} disabled={running} class="bg-blue-500 text-white px-4 py-2 rounded">
      {running ? 'Merging...' : 'Start Merge'}
    </button>
    {#if running}
      <button on:click={cancelMerge} class="bg-red-500 text-white px-4 py-2 rounded">
        Cancel
      </button>
    {/if}
  </div>

  <textarea
    readonly
    rows="15"
    bind:value={output}
    class="w-full border p-2 rounded font-mono bg-gray-100 resize-none overflow-y-auto"
  ></textarea>
  </div>
</div>