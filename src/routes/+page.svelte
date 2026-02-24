<script lang="ts">
  let folderPath1 = '';
  let folderPath2 = '';
  let output = '';
  let running = false;

  async function startMerge() {
    output = '';
    running = true;

    const res = await fetch('/api/start-merge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ folder1: folderPath1, folder2: folderPath2 })
    });

    const reader = res.body?.getReader();
    if (!reader) return;

    const decoder = new TextDecoder();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      output += decoder.decode(value, { stream: true });
    }

    running = false;
  }
</script>

<div class="min-h-screen flex items-center justify-center bg-gray-100 p-4">
  <div class="bg-white shadow-lg rounded-lg p-8 w-full max-w-lg flex flex-col gap-6">
    <h1 class="text-2xl font-bold text-gray-800">Merge Folders</h1>

    <!-- Folder Inputs -->
    <input
      type="text"
      placeholder="Input path"
      bind:value={folderPath1}
      class="w-full border border-gray-300 rounded px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-transparent"
    />
    <input
      type="text"
      placeholder="Output path"
      bind:value={folderPath2}
      class="w-full border border-gray-300 rounded px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-transparent"
    />

    <!-- Start Merge Button -->
    <button
      on:click={startMerge}
      class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded shadow"
      disabled={running}
    >
      {running ? 'Merging...' : 'Start Merge'}
    </button>

    <!-- Live Output -->
    <textarea
      readonly
      rows="12"
      class="w-full border border-gray-300 rounded p-2 bg-gray-100 text-sm font-mono resize-none overflow-y-auto"
      bind:value={output}
    ></textarea>
  </div>
</div>