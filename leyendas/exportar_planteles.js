// Copia los planteles y camisetas de clasico.html al juego de Godot.
// Uso: node leyendas/exportar_planteles.js
const fs = require('fs'), path = require('path'), vm = require('vm');
const html = fs.readFileSync(path.join(__dirname, 'clasico.html'), 'utf8');
const js = html.split('<script>')[1].split('</script>')[0];
const ctx = { module: { exports: {} }, console };
vm.runInNewContext(js, ctx);
const src = vm.runInNewContext('({TEAMS, FORM, GK_KITS})', Object.assign(ctx, {}));
const keep = ['n', 'pos', 'o', 'sk', 'hc', 'hs', 'mus', 'band', 'vel', 'def', 'pas', 'reg', 'tir', 'ata', 'tr'];
const out = {
  formaciones: src.FORM,
  kits_arquero: src.GK_KITS,
  equipos: src.TEAMS.map(t => ({
    id: t.id, nombre: t.name, codigo: t.code, puntos: t.pts, esquema: t.form, camisetas: t.kits,
    jugadores: t.players.map(p => Object.fromEntries(keep.map(k => [k, p[k] === undefined ? '' : p[k]])))
  }))
};
const dest = path.join(__dirname, 'godot', 'data', 'equipos.json');
fs.writeFileSync(dest, JSON.stringify(out, null, 1));
console.log('Escrito', dest, out.equipos.length, 'equipos');
