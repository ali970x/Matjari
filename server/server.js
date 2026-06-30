const app = require('./src/app');
const env = require('./src/config/env');
const { initStore } = require('./src/services/store');

async function start() {
  await initStore();

  app.listen(env.port, () => {
    console.log(`Matjari API running on http://localhost:${env.port}`);
  });
}

start().catch((error) => {
  console.error('Failed to start Matjari API');
  console.error(error);
  process.exit(1);
});
