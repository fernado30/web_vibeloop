import { mkdir, readFile, writeFile, copyFile, access } from 'node:fs/promises';
import { join } from 'node:path';
import { constants } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const distDir = join(root, 'dist');

const requiredEnv = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'VIBELOOP_BACKEND_URL'];

function readEnv(name) {
  return process.env[name]?.trim() ?? '';
}

function assertEnv(name, value) {
  if (!value || value.includes('YOUR_')) {
    throw new Error(`Missing or placeholder env var: ${name}`);
  }
}

async function main() {
  for (const name of requiredEnv) {
    assertEnv(name, readEnv(name));
  }

  await mkdir(distDir, { recursive: true });
  await mkdir(join(distDir, '.well-known'), { recursive: true });

  // The root domain is the public landing page. The inbox remains a separate
  // document and is reached only through the token routes configured in Vercel.
  await mkdir(join(distDir, 'buzon'), { recursive: true });
  await copyFile(join(root, '..', 'landing', 'index.html'), join(distDir, 'index.html'));
  await copyFile(join(root, '..', 'landing', 'hero-sculpture-v1.png'), join(distDir, 'hero-sculpture-v1.png'));
  await copyFile(join(root, '..', 'landing', 'nadie-chat-vecinos.jpeg'), join(distDir, 'nadie-chat-vecinos.jpeg'));
  await copyFile(join(root, '..', 'landing', 'nadie-galeria-usuario.jpeg'), join(distDir, 'nadie-galeria-usuario.jpeg'));
  await copyFile(join(root, '..', 'landing', 'nadie-crea-grupo.jpeg'), join(distDir, 'nadie-crea-grupo.jpeg'));
  await copyFile(join(root, '..', 'landing', 'nadie-invitar.jpeg'), join(distDir, 'nadie-invitar.jpeg'));
  await copyFile(join(root, 'index.html'), join(distDir, 'buzon', 'index.html'));
  await copyFile(join(root, 'styles.css'), join(distDir, 'styles.css'));
  await copyFile(join(root, 'app.js'), join(distDir, 'app.js'));
  await copyFile(join(root, 'vibeloop-icon.png'), join(distDir, 'vibeloop-icon.png'));
  try {
    await access(join(root, '.well-known', 'assetlinks.json'), constants.R_OK);
    await copyFile(join(root, '.well-known', 'assetlinks.json'), join(distDir, '.well-known', 'assetlinks.json'));
  } catch (_) {
    // App Links are optional during local builds.
  }

  const config = {
    backendUrl: readEnv('VIBELOOP_BACKEND_URL'),
    supabaseUrl: readEnv('SUPABASE_URL'),
    supabaseAnonKey: readEnv('SUPABASE_ANON_KEY'),
  };

  await writeFile(
    join(distDir, 'config.js'),
    `window.VIBELOOP_WEB_CONFIG = ${JSON.stringify(config, null, 2)};\n`,
    'utf8',
  );

  await writeFile(
    join(distDir, '404.html'),
    await readFile(join(distDir, 'index.html'), 'utf8'),
    'utf8',
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
