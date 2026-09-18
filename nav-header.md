%%
Служебная заметка Obsiclipcapture.
Оригинал лежит в каталоге утилиты, в файле nav-header.md.
Эта копия перезаписывается утилитой при запуске и перед созданием новой ежедневки,
поэтому правки, сделанные здесь, будут потеряны — меняйте оригинал.
%%

```dataviewjs
// !!! НЕ СТИРАТЬ !!! СЛУЖЕБНЫЙ КОД НАВИГАЦИИ ПО ЕЖЕДНЕВКАМ !!!

(function () {

    const NAME      = "Навигация_ежедневок";  // как называется эта заметка
    const TAG       = "ежедневка";            // без октоторпа, код подставит сам
    const NAME_PART = "ежедневка";            // слово в названии файла; пусто — не проверять
    const BY_DATE   = true;                   // считать ежедневкой любую заметку с датой в названии
    const FOLDER    = "";                     // сузить поиск папкой; пусто — всё хранилище
    const DATEPROP  = "создано";
    const SKIP      = ["Serv"];
    const A_PREV    = "⟵";
    const A_NEXT    = "⟶";
    const A_DICE    = "⚄";
    const FACES     = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"];
    const D_SIZE    = "25px";                 // размер кубика; стрелки — 15px
    const CLS       = "yule-daily-nav";
    const GLOBAL    = "__yuleDailyNav";

    // ── теги заметки обычным массивом ──
    function tagList(p) {
        const t = p.file.tags;
        if (!t) return [];
        if (Array.isArray(t)) return t;
        if (t.array)  return t.array();
        if (t.values) return t.values;
        return [];
    }

    // ── месяц словом ──
    const M_ROOTS = [
        ["сентябр", 9], ["феврал", 2], ["октябр", 10], ["декабр", 12],
        ["январ", 1], ["апрел", 4], ["август", 8], ["ноябр", 11],
        ["март", 3], ["июн", 6], ["июл", 7], ["ма", 5]
    ];
    function monthFromWord(w) {
        w = w.toLowerCase();
        for (let i = 0; i < M_ROOTS.length; i++)
            if (w.indexOf(M_ROOTS[i][0]) === 0) return M_ROOTS[i][1];
        return 0;
    }

    function mk(y, mo, d) {
        if (!(mo >= 1 && mo <= 12) || !(d >= 1 && d <= 31)) return null;
        if (!(y >= 1900 && y <= 2999)) return null;
        return Date.UTC(y, mo - 1, d);
    }

    // ── дата из имени файла: год впереди, год позади, слитно, месяц словом ──
    function dateFromName(s) {
        let m;
        m = s.match(/(?:^|\D)(\d{4})[-_. ](\d{1,2})[-_. ](\d{1,2})(?!\d)/);
        if (m) { const r = mk(+m[1], +m[2], +m[3]); if (r !== null) return r; }

        m = s.match(/(?:^|\D)(\d{1,2})[-_. ](\d{1,2})[-_. ](\d{4})(?!\d)/);
        if (m) { const r = mk(+m[3], +m[2], +m[1]); if (r !== null) return r; }

        m = s.match(/(?:^|\D)(\d{4})(\d{2})(\d{2})(?!\d)/);
        if (m) { const r = mk(+m[1], +m[2], +m[3]); if (r !== null) return r; }

        m = s.match(/(\d{1,2})[-_. ]*([А-Яа-яЁё]{3,})[-_. ]*(\d{4})/);
        if (m) {
            const mo = monthFromWord(m[2]);
            if (mo) { const r = mk(+m[3], mo, +m[1]); if (r !== null) return r; }
        }

        m = s.match(/([А-Яа-яЁё]{3,})[-_. ]*(\d{1,2})[-_. ]*(\d{4})/);
        if (m) {
            const mo = monthFromWord(m[1]);
            if (mo) { const r = mk(+m[3], mo, +m[2]); if (r !== null) return r; }
        }
        return null;
    }

    // ── дата из свойства ──
    function dateFromProp(v) {
        if (!v) return null;
        if (v.ts) return v.ts;
        return dateFromName(String(v).trim());
    }

    // ── ежедневка: тег, слово в названии или дата в названии ──
    function isDaily(p) {
        for (let i = 0; i < SKIP.length; i++)
            if (p.file.path.indexOf(SKIP[i] + "/") === 0) return false;
        if (NAME_PART &&
            p.file.name.toLowerCase().indexOf(NAME_PART.toLowerCase()) >= 0) return true;
        if (TAG) {
            const want = ("#" + TAG).toLowerCase();
            const list = tagList(p);
            for (let i = 0; i < list.length; i++)
                if (String(list[i]).toLowerCase() === want) return true;
        }
        if (BY_DATE && dateFromName(p.file.name) !== null) return true;
        return false;
    }

    // ── дата заметки: свойство, иначе имя файла, иначе дата файла ──
    function noteDate(p) {
        const a = dateFromProp(p[DATEPROP]);
        if (a !== null) return a;
        const b = dateFromName(p.file.name);
        if (b !== null) return b;
        return p.file.ctime ? p.file.ctime.ts : 0;
    }

    // ── список ежедневок по возрастанию даты ──
    function dailyList() {
        const src = FOLDER ? '"' + FOLDER + '"' : "";
        return dv.pages(src).array()
            .filter(isDaily)
            .map(function (p) {
                return { path: p.file.path, name: p.file.name, d: noteDate(p) };
            })
            .sort(function (a, b) { return a.d - b.d; });
    }

    // ── угол с двумя стрелками для одной панели ──
    function drawCorner(sizer, all, idx) {
        const prev = (idx > 0) ? all[idx - 1] : null;
        const next = (idx < all.length - 1) ? all[idx + 1] : null;

        const now     = new Date();
        const today   = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
        const isToday = all[idx].d === today;

        const corner = sizer.createEl("div", { cls: CLS });
        corner.style.cssText = [
            "position:absolute", "top:0", "right:14px", "z-index:10",
            "display:flex", "gap:2px", "align-items:center",
            "padding:2px 5px 3px 8px",
            "background:var(--background-primary)",
            "border-left:1px solid var(--background-modifier-border)",
            "border-bottom:1px solid var(--background-modifier-border)",
            "border-radius:0 0 0 10px"
        ].join(";");

        function open(rec) {
            if (rec) app.workspace.openLinkText(rec.path, "", false);
        }

        // ── случайная ежедневка, кроме текущей; бросок при каждом щелчке ──
        function roll() {
            if (all.length < 2) return null;
            let j = idx;
            for (let t = 0; t < 24 && j === idx; t++)
                j = Math.floor(Math.random() * all.length);
            return (j === idx) ? null : all[j];
        }

        function addBtn(glyph, off, hint, act) {
            const b = corner.createEl("div", { text: glyph });
            b.style.cssText = [
                "font-size:15px", "line-height:1",
                "padding:3px 7px", "border-radius:5px", "user-select:none",
                "color:" + (off ? "var(--text-faint)" : "var(--text-muted)"),
                "cursor:" + (off ? "default" : "pointer")
            ].join(";");
            b.setAttribute("aria-label", hint);
            if (off) return b;
            b.onmouseenter = function () {
                b.style.color = "var(--text-normal)";
                b.style.background = "var(--background-modifier-hover)";
            };
            b.onmouseleave = function () {
                b.style.color = "var(--text-muted)";
                b.style.background = "transparent";
            };
            b.onclick = act;
            return b;
        }

        addBtn(A_PREV, !prev,
               prev ? "Предыдущая: " + prev.name : "Предыдущей ежедневки нет",
               function () { open(prev); });

        const dice = addBtn(A_DICE, all.length < 2,
               all.length < 2 ? "Других ежедневок нет" : "Случайная ежедневка",
               function () { open(roll()); });
        dice.style.fontSize = D_SIZE;
        dice.style.padding  = "0 4px";

        if (all.length > 1) {
            dice.addEventListener("mouseenter", function () {
                dice.textContent = FACES[Math.floor(Math.random() * FACES.length)];
            });
        }

        addBtn(A_NEXT, isToday || !next,
               isToday ? "Это сегодняшняя ежедневка"
                       : (next ? "Следующая: " + next.name : "Следующей ежедневки нет"),
               function () { open(next); });
    }

    // ── обход всех панелей: снести старые углы, нарисовать по текущему файлу ──
    function refreshAll() {
        let all = null;
        app.workspace.iterateAllLeaves(function (l) {
            const el    = l.containerEl;
            const sizer = el ? el.querySelector(".cm-sizer") : null;
            if (!sizer) return;

            sizer.querySelectorAll("." + CLS).forEach(function (n) { n.remove(); });

            const file = (l.view && l.view.file) ? l.view.file : null;
            if (!file) return;

            if (all === null) { try { all = dailyList(); } catch (e) { all = []; } }
            const idx = all.findIndex(function (r) { return r.path === file.path; });
            if (idx < 0) return;

            drawCorner(sizer, all, idx);
        });
    }

    function schedule() { setTimeout(refreshAll, 60); }

    // ── наблюдатель: один на сеанс, перерисовывает при смене заметки ──
    if (!window[GLOBAL]) {
        window[GLOBAL] = { run: schedule };
        app.workspace.on("file-open",          function () { window[GLOBAL].run(); });
        app.workspace.on("active-leaf-change", function () { window[GLOBAL].run(); });
        app.workspace.on("layout-change",      function () { window[GLOBAL].run(); });
    } else {
        // блок исполнился заново — подхватить изменённые константы
        window[GLOBAL].run = schedule;
    }

    window[GLOBAL].run();

    // ── спрятать собственное встраивание ──
    // Только в конце и только на своём элементе: заранее спрятанное
    // встраивание Obsidian не станет рисовать, и блок не исполнится.
    setTimeout(function () {
        const c = dv.container;
        if (!c || !c.closest) return;
        const emb = c.closest(".cm-embed-block") || c.closest(".internal-embed");
        if (emb) emb.style.display = "none";
    }, 60);

})();
```
