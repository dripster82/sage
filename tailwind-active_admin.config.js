const execSync = require('child_process').execSync;
const activeAdminPath = execSync('bundle show activeadmin', { encoding: 'utf-8' }).trim();

module.exports = {
  content: [
    `${activeAdminPath}/vendor/javascript/flowbite.js`,
    `${activeAdminPath}/plugin.js`,
    `${activeAdminPath}/app/views/**/*.{arb,erb,html,rb}`,
    './app/admin/**/*.{arb,erb,html,rb}',
    './app/views/**/*.{arb,erb,html,rb}',
    './app/views/layouts/active_admin*.{erb,html}',
    './app/javascript/**/*.js',
    './app/assets/stylesheets/**/*.{css,scss,sass}'
  ],
  safelist: [
    'grid',
    'grid-cols-1',
    'grid-cols-2',
    'grid-cols-3',
    'grid-cols-4',
    'grid-cols-5',
    'md:grid-cols-1',
    'md:grid-cols-2',
    'md:grid-cols-3',
    'md:grid-cols-4',
    'md:grid-cols-5',
    'gap-6',
    'gap-4',
    'gap-2'
  ],
  darkMode: "selector",
  plugins: [
    require(`@activeadmin/activeadmin/plugin`)
  ]
}
