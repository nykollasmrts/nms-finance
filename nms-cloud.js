/* NMS · conexão com o Supabase
   Faz o papel do armazenamento: guarda cada registro numa tabela "docs" e avisa a tela
   quando algo muda. Sem configuração, o app abre em modo demonstração (dados no navegador). */
(function () {
  const CFG = window.NMS_CONFIG || {};
  const ok = CFG.supabaseUrl && CFG.supabaseAnonKey && !/COLE_AQUI/.test(CFG.supabaseUrl + CFG.supabaseAnonKey) && window.supabase;
  const SB = ok ? window.supabase.createClient(CFG.supabaseUrl, CFG.supabaseAnonKey, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }) : null;
  window.NMS_SB = SB;
  window.NMS_PROFILE = null;

  const rnd = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
  const parentOf = p => p.split("/").slice(0, -1).join("/");
  const meta = { fromCache: false, hasPendingWrites: false };
  const snap = (row, id) => ({ id, exists: !!row, data: () => (row ? row.data : undefined), metadata: meta });
  const fail = e => ({ code: /row-level|violates|inválido/i.test(e && e.message || "") ? "invalid_argument" : "unavailable", message: e && e.message || "erro" });

  const watchers = new Set();
  function watch(filter, pull, onErr) {
    let alive = true, t = null;
    const run = () => { clearTimeout(t); t = setTimeout(() => { if (alive) pull().catch(e => onErr && onErr(fail(e))); }, 150); };
    run();
    const ch = SB.channel("nms-" + rnd()).on("postgres_changes", { event: "*", schema: "public", table: "docs", filter }, run).subscribe();
    const w = { run }; watchers.add(w);
    return () => { alive = false; watchers.delete(w); try { SB.removeChannel(ch); } catch {} };
  }
  // exclusões não chegam filtradas pelo tempo real; por isso a tela também se atualiza a cada 30 s e ao voltar para a janela
  setInterval(() => watchers.forEach(w => w.run()), 30000);
  window.addEventListener("focus", () => watchers.forEach(w => w.run()));
  document.addEventListener("visibilitychange", () => { if (!document.hidden) watchers.forEach(w => w.run()); });

  function doc(path) {
    const id = path.split("/").pop();
    const ref = {
      id, path,
      async get() { const { data, error } = await SB.from("docs").select("data").eq("path", path).maybeSingle(); if (error) throw fail(error); return snap(data, id); },
      async set(body) { const { error } = await SB.from("docs").upsert({ path, parent: parentOf(path), data: body, updated_at: new Date().toISOString() }); if (error) throw fail(error); },
      async update(body) { const s = await ref.get(); if (!s.exists) throw { code: "invalid_argument", message: "não existe" }; return ref.set({ ...s.data(), ...body }); },
      async delete() { const { error } = await SB.from("docs").delete().eq("path", path); if (error) throw fail(error); },
      onSnapshot(next, onErr) { return watch(`path=eq.${path}`, async () => next(await ref.get()), onErr); },
      collection(name) { return col(path + "/" + name); },
    };
    return ref;
  }
  function col(path) {
    const ref = {
      path,
      doc(id) { return doc(path + "/" + (id || rnd())); },
      async add(body) { const d = ref.doc(); await d.set(body); return d; },
      async get() {
        const { data, error } = await SB.from("docs").select("path,data").eq("parent", path).limit(5000);
        if (error) throw fail(error);
        const docs = data.map(r => snap(r, r.path.split("/").pop()));
        return { docs, size: docs.length, empty: !docs.length, docChanges: () => [], metadata: meta };
      },
      onSnapshot(next, onErr) { return watch(`parent=eq.${path}`, async () => next(await ref.get()), onErr); },
    };
    return ref;
  }

  async function loadProfile() {
    if (!SB) return null;
    const { data: s } = await SB.auth.getSession(); const u = s.session && s.session.user; if (!u) return null;
    const { data } = await SB.from("profiles").select("*").eq("id", u.id).maybeSingle();
    window.NMS_PROFILE = data || { id: u.id, nome: (u.user_metadata && u.user_metadata.nome) || "", tipo: (u.user_metadata && u.user_metadata.tipo) || "pf", role: "user" };
    return window.NMS_PROFILE;
  }
  window.NMS_loadProfile = loadProfile;

  // mesma interface que o app usava dentro do Claude
  window.claude = {
    use: async name => {
      if (!SB) return null;
      const { data } = await SB.auth.getSession(); const u = data.session && data.session.user; if (!u) return null;
      if (!window.NMS_PROFILE) await loadProfile();
      const P = () => window.NMS_PROFILE || {};
      if (name === "db") return { doc, collection: col };
      if (name === "user") return {
        id: async () => u.id,
        isOwner: async () => P().role === "master",
        canEdit: async () => P().role === "master",
        can: async () => null,
        me: async () => ({ id: u.id, name: P().nome || "", email: u.email, isOwner: P().role === "master", canEdit: P().role === "master", avatarUrl: "", color: "" }),
        profiles: async ids => {
          const out = {}, real = [...new Set(ids.map(i => String(i).split(":")[0]))];
          ids.forEach(i => { out[i] = { id: i, name: "", isMe: i === u.id }; });
          const { data: rows } = await SB.from("profiles").select("id,nome").in("id", real);
          (rows || []).forEach(p => { out[p.id] = { id: p.id, name: p.nome || "", isMe: p.id === u.id }; });
          return out;
        },
      };
      return null; // chat inteligente e leitura de PDF ficam no modo simples fora do Claude
    },
  };
})();
