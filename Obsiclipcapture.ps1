#Requires -Version 5.1
# OBSICLIPCAPTURE — клиппер + быстрые заметки в одном процессе
# Запуск: start.vbs  |  При ошибке — см. obsiclipcapture.log рядом со скриптом

$ScriptDir    = if ($PSScriptRoot) { $PSScriptRoot } `
                else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$SettingsFile = Join-Path $ScriptDir "obsiclipcapture.cfg"
$LogFile      = Join-Path $ScriptDir "obsiclipcapture.log"

function Write-Log($msg) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$stamp] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 3
Write-Log "=== START  ScriptDir=$ScriptDir"
Write-Log "SettingsFile=$SettingsFile  Exists=$(Test-Path $SettingsFile)"

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing       -ErrorAction Stop
    Write-Log "Assemblies OK"
} catch {
    Write-Log "FATAL assembly: $_"
    exit 1
}

try {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Diagnostics;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Collections.Generic;

// ════════════════════════════════════════════════════════════
// Настройки — одна связка на клип и капчу
// ════════════════════════════════════════════════════════════
public class AppSettings {
    public static readonly string[] KEY_NAMES = {
        "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"
    };
    public static readonly uint[] KEY_VKS = {
        0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B
    };

    // Голый модификатор для капчи: RegisterHotKey одиночный модификатор не берёт,
    // поэтому такие хоткеи ловятся опросом GetAsyncKeyState.
    public static readonly string[] BARE_NAMES = {
        "(не использовать)","правый Alt","правый Ctrl","правый Shift","левый Alt"
    };
    public static readonly int[] BARE_VKS = { 0, 0xA5, 0xA3, 0xA1, 0xA4 };

    public string SettingsPath  { get; set; }

    // ── общее ───────────────────────────────────────────────
    public string VaultPath     { get; set; }

    // ── клип ────────────────────────────────────────────────
    public string Inbox         { get; set; }
    public string Attachments   { get; set; }
    public string DatePropName  { get; set; }
    public string DateFormat    { get; set; }
    public List<string[]> Props { get; set; }
    public string TemplaterCmd  { get; set; }
    public bool   HotkeyCtrl    { get; set; }
    public bool   HotkeyAlt     { get; set; }
    public bool   HotkeyShift   { get; set; }
    public uint   HotkeyVk      { get; set; }

    // ── капча ───────────────────────────────────────────────
    public string CapFolder     { get; set; }
    public string CapFileName   { get; set; }
    public string CapHeader     { get; set; }
    public string NavSource     { get; set; }
    public string NavTarget     { get; set; }
    public string CapEntry      { get; set; }
    public string CapSeparator  { get; set; }
    public List<string[]> CapProps { get; set; }
    public bool   CapHkCtrl     { get; set; }
    public bool   CapHkAlt      { get; set; }
    public bool   CapHkShift    { get; set; }
    public uint   CapHkVk       { get; set; }
    public int    CapHkBare     { get; set; }
    public string CapTheme      { get; set; }
    public string CapFont       { get; set; }
    public int    CapFontSize   { get; set; }
    public int    CapFlash      { get; set; }
    public int    CapW          { get; set; }
    public int    CapH          { get; set; }
    public int    CapX          { get; set; }
    public int    CapY          { get; set; }

    public AppSettings(string path) {
        SettingsPath = path;
        Attachments  = "Serv\\Attachments";
        DatePropName = "date";
        DateFormat   = "yyyy-MM-dd";
        Props        = new List<string[]>();
        HotkeyCtrl   = true;
        HotkeyAlt    = true;
        HotkeyShift  = false;
        HotkeyVk     = 0x77;

        CapFolder    = "Накопитель";
        CapFileName  = "{date:yyyy-MM-dd}-ежедневка.md";
        CapHeader    = "![[Навигация_ежедневок]]";
        NavSource    = "nav-header.md";
        NavTarget    = "Serv\\Scripts\\Навигация_ежедневок.md";
        CapEntry     = "{clock} {text}";
        CapSeparator = "\n\n";
        CapProps     = new List<string[]>();
        CapHkCtrl    = false;
        CapHkAlt     = false;
        CapHkShift   = false;
        CapHkVk      = 0;
        CapHkBare    = 1;              // правый Alt
        CapTheme     = "light";
        CapFont      = "Segoe UI";
        CapFontSize  = 11;
        CapFlash     = 3;
        CapW = 520; CapH = 200; CapX = -1; CapY = -1;
    }

    static string Esc(string s)   { return (s ?? "").Replace("\r","").Replace("\n","\\n"); }
    static string Unesc(string s) { return (s ?? "").Replace("\\n","\n"); }

    public bool Load() {
        if (!File.Exists(SettingsPath)) return false;
        try {
            var pnames   = new Dictionary<int, string>();
            var pvalues  = new Dictionary<int, string>();
            var cnames   = new Dictionary<int, string>();
            var cvalues  = new Dictionary<int, string>();
            string legacyName = null, legacyVal = null;
            foreach (string raw in File.ReadAllLines(SettingsPath, Encoding.UTF8)) {
                int eq = raw.IndexOf('=');
                if (eq < 0) continue;
                string k = raw.Substring(0, eq).Trim().ToLower();
                string v = raw.Substring(eq + 1);
                switch (k) {
                    case "vaultpath":    VaultPath    = v; break;
                    case "inbox":        Inbox        = v; break;
                    case "attachments":  Attachments  = v; break;
                    case "datepropname": DatePropName = v; break;
                    case "dateformat":   DateFormat   = v; break;
                    case "templatercmd": TemplaterCmd = v; break;
                    case "hotkey_ctrl":  HotkeyCtrl  = (v == "true"); break;
                    case "hotkey_alt":   HotkeyAlt   = (v == "true"); break;
                    case "hotkey_shift": HotkeyShift = (v == "true"); break;
                    case "hotkey_vk": {
                        uint vk; if (uint.TryParse(v, out vk)) HotkeyVk = vk; break;
                    }
                    case "cap_folder":    CapFolder    = v; break;
                    case "cap_filename":  CapFileName  = v; break;
                    case "cap_header":    CapHeader    = Unesc(v); break;
                    case "nav_source":    NavSource    = v; break;
                    case "nav_target":    NavTarget    = v; break;
                    case "cap_entry":     CapEntry     = Unesc(v); break;
                    case "cap_separator": CapSeparator = Unesc(v); break;
                    case "cap_theme":     CapTheme     = v; break;
                    case "cap_font":      CapFont      = v; break;
                    case "cap_hk_ctrl":   CapHkCtrl  = (v == "true"); break;
                    case "cap_hk_alt":    CapHkAlt   = (v == "true"); break;
                    case "cap_hk_shift":  CapHkShift = (v == "true"); break;
                    case "cap_hk_vk":   { uint u; if (uint.TryParse(v, out u)) CapHkVk    = u; break; }
                    case "cap_hk_bare": { int  i; if (int.TryParse(v,  out i)) CapHkBare  = i; break; }
                    case "cap_fontsize":{ int  i; if (int.TryParse(v,  out i)) CapFontSize= i; break; }
                    case "cap_flash":   { int  i; if (int.TryParse(v,  out i)) CapFlash   = i; break; }
                    case "cap_w":       { int  i; if (int.TryParse(v,  out i)) CapW = i; break; }
                    case "cap_h":       { int  i; if (int.TryParse(v,  out i)) CapH = i; break; }
                    case "cap_x":       { int  i; if (int.TryParse(v,  out i)) CapX = i; break; }
                    case "cap_y":       { int  i; if (int.TryParse(v,  out i)) CapY = i; break; }
                    case "propname":  legacyName = v; break;
                    case "propvalue": legacyVal  = v; break;
                    default: {
                        if (k.StartsWith("cap_prop_name_")) {
                            int idx; if (int.TryParse(k.Substring(14), out idx)) cnames[idx] = v;
                        } else if (k.StartsWith("cap_prop_value_")) {
                            int idx; if (int.TryParse(k.Substring(15), out idx)) cvalues[idx] = v;
                        } else if (k.StartsWith("prop_name_")) {
                            int idx; if (int.TryParse(k.Substring(10), out idx)) pnames[idx] = v;
                        } else if (k.StartsWith("prop_value_")) {
                            int idx; if (int.TryParse(k.Substring(11), out idx)) pvalues[idx] = v;
                        }
                        break;
                    }
                }
            }
            Props = new List<string[]>();
            for (int i = 0; i < 100; i++) {
                if (!pnames.ContainsKey(i)) break;
                Props.Add(new string[] { pnames[i], pvalues.ContainsKey(i) ? pvalues[i] : "" });
            }
            if (Props.Count == 0 && legacyName != null)
                Props.Add(new string[] { legacyName, legacyVal ?? "" });

            CapProps = new List<string[]>();
            for (int i = 0; i < 100; i++) {
                if (!cnames.ContainsKey(i)) break;
                CapProps.Add(new string[] { cnames[i], cvalues.ContainsKey(i) ? cvalues[i] : "" });
            }
            return !string.IsNullOrEmpty(VaultPath);
        } catch { return false; }
    }

    public void Save() {
        var lines = new List<string>();
        lines.Add("vaultpath="    + (VaultPath    ?? ""));
        lines.Add("inbox="        + (Inbox        ?? ""));
        lines.Add("attachments="  + (Attachments  ?? ""));
        lines.Add("datepropname=" + (DatePropName ?? "date"));
        lines.Add("dateformat="   + (DateFormat   ?? "yyyy-MM-dd"));
        lines.Add("templatercmd=" + (TemplaterCmd ?? ""));
        lines.Add("hotkey_ctrl="  + HotkeyCtrl.ToString().ToLower());
        lines.Add("hotkey_alt="   + HotkeyAlt.ToString().ToLower());
        lines.Add("hotkey_shift=" + HotkeyShift.ToString().ToLower());
        lines.Add("hotkey_vk="    + HotkeyVk.ToString());
        for (int i = 0; i < Props.Count; i++) {
            lines.Add("prop_name_"  + i + "=" + Props[i][0]);
            lines.Add("prop_value_" + i + "=" + (Props[i].Length > 1 ? Props[i][1] : ""));
        }
        lines.Add("cap_folder="    + (CapFolder   ?? ""));
        lines.Add("cap_filename="  + (CapFileName ?? ""));
        lines.Add("cap_header="    + Esc(CapHeader));
        lines.Add("nav_source="    + (NavSource ?? ""));
        lines.Add("nav_target="    + (NavTarget ?? ""));
        lines.Add("cap_entry="     + Esc(CapEntry));
        lines.Add("cap_separator=" + Esc(CapSeparator));
        lines.Add("cap_hk_ctrl="   + CapHkCtrl.ToString().ToLower());
        lines.Add("cap_hk_alt="    + CapHkAlt.ToString().ToLower());
        lines.Add("cap_hk_shift="  + CapHkShift.ToString().ToLower());
        lines.Add("cap_hk_vk="     + CapHkVk.ToString());
        lines.Add("cap_hk_bare="   + CapHkBare.ToString());
        lines.Add("cap_theme="     + (CapTheme ?? "light"));
        lines.Add("cap_font="      + (CapFont  ?? "Segoe UI"));
        lines.Add("cap_fontsize="  + CapFontSize.ToString());
        lines.Add("cap_flash="     + CapFlash.ToString());
        lines.Add("cap_w=" + CapW); lines.Add("cap_h=" + CapH);
        lines.Add("cap_x=" + CapX); lines.Add("cap_y=" + CapY);
        for (int i = 0; i < CapProps.Count; i++) {
            lines.Add("cap_prop_name_"  + i + "=" + CapProps[i][0]);
            lines.Add("cap_prop_value_" + i + "=" + (CapProps[i].Length > 1 ? CapProps[i][1] : ""));
        }
        File.WriteAllLines(SettingsPath, lines.ToArray(), Encoding.UTF8);
    }

    public uint GetMod() {
        uint m = 0;
        if (HotkeyCtrl)  m |= 0x0002;
        if (HotkeyAlt)   m |= 0x0001;
        if (HotkeyShift) m |= 0x0004;
        return m;
    }
    public uint GetCapMod() {
        uint m = 0;
        if (CapHkCtrl)  m |= 0x0002;
        if (CapHkAlt)   m |= 0x0001;
        if (CapHkShift) m |= 0x0004;
        return m;
    }

    public string GetHotkeyDisplay() {
        string s = "";
        if (HotkeyCtrl)  s += "Ctrl+";
        if (HotkeyAlt)   s += "Alt+";
        if (HotkeyShift) s += "Shift+";
        int idx = Array.IndexOf(KEY_VKS, HotkeyVk);
        return s + (idx >= 0 ? KEY_NAMES[idx] : "?");
    }
    public string GetCapHotkeyDisplay() {
        if (CapHkBare > 0 && CapHkBare < BARE_NAMES.Length) return BARE_NAMES[CapHkBare];
        string s = "";
        if (CapHkCtrl)  s += "Ctrl+";
        if (CapHkAlt)   s += "Alt+";
        if (CapHkShift) s += "Shift+";
        int idx = Array.IndexOf(KEY_VKS, CapHkVk);
        return (idx >= 0) ? s + KEY_NAMES[idx] : "—";
    }
    public bool CapUsesBare() {
        return CapHkBare > 0 && CapHkBare < BARE_VKS.Length;
    }
    public bool CapUsesRegistered() {
        return !CapUsesBare() && Array.IndexOf(KEY_VKS, CapHkVk) >= 0;
    }

    // ── подстановки в шаблонах ──────────────────────────────
    public static string Clock(DateTime now) {
        int h = now.Hour % 12; if (h == 0) h = 12;
        int base_ = (now.Minute >= 30) ? 0x1F55C : 0x1F550;
        return char.ConvertFromUtf32(base_ + h - 1);
    }
    public static string Expand(string tpl, DateTime now, string text) {
        if (tpl == null) return "";
        string s = tpl;
        int guard = 0;
        while (guard++ < 40) {
            int a = s.IndexOf("{date:");
            if (a < 0) break;
            int b = s.IndexOf('}', a);
            if (b < 0) break;
            string fmt = s.Substring(a + 6, b - a - 6);
            string val;
            try { val = now.ToString(fmt); } catch { val = fmt; }
            s = s.Substring(0, a) + val + s.Substring(b + 1);
        }
        return s.Replace("{clock}", Clock(now)).Replace("{text}", text ?? "");
    }
}

// ════════════════════════════════════════════════════════════
// Служебная заметка навигации: оригинал лежит рядом со скриптом,
// в хранилище уезжает копия. Проверяется при запуске, после
// сохранения настроек и перед созданием каждой новой ежедневки.
// ════════════════════════════════════════════════════════════
public static class Nav {
    public static string LastError = "";

    public static string SourcePath(AppSettings st) {
        if (string.IsNullOrEmpty(st.NavSource)) return null;
        string dir = Path.GetDirectoryName(st.SettingsPath ?? "");
        if (string.IsNullOrEmpty(dir)) return null;
        return Path.Combine(dir, st.NavSource);
    }

    public static string TargetPath(AppSettings st) {
        if (string.IsNullOrEmpty(st.NavTarget)) return null;
        if (string.IsNullOrEmpty(st.VaultPath)) return null;
        return Path.Combine(st.VaultPath, st.NavTarget);
    }

    // true — заметка была записана заново
    public static bool Ensure(AppSettings st) {
        LastError = "";
        try {
            string src = SourcePath(st);
            string dst = TargetPath(st);
            if (src == null || dst == null) return false;
            if (!File.Exists(src)) {
                LastError = "Файл " + st.NavSource + " не найден рядом со скриптом";
                return false;
            }
            var enc  = new UTF8Encoding(false);
            string want = File.ReadAllText(src, enc);
            if (File.Exists(dst) && File.ReadAllText(dst, enc) == want) return false;
            string dir = Path.GetDirectoryName(dst);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            File.WriteAllText(dst, want, enc);
            return true;
        } catch (Exception ex) {
            LastError = ex.Message;
            return false;
        }
    }
}

// ════════════════════════════════════════════════════════════
// Окно настроек клипа
// ════════════════════════════════════════════════════════════
public class SettingsForm : Form {
    public AppSettings Result;
    TextBox txVault, txInbox, txAttach, txDateProp, txDate, txTmpl;
    DataGridView dgvProps;
    CheckBox ckCtrl, ckAlt, ckShift;
    ComboBox cbKey;

    public SettingsForm(AppSettings s) {
        Text = "Настройки клиппера";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition   = FormStartPosition.CenterScreen;
        ClientSize      = new Size(488, 592);
        MaximizeBox = false; MinimizeBox = false;
        TopMost = true;

        int lx = 12, rw = 464, y = 12;

        AddL("Путь к хранилищу Obsidian (полный):", lx, y, rw); y += 20;
        txVault = AddT(s.VaultPath ?? "", lx, y, rw); y += 34;

        AddL("Папка для заметок:", lx, y, 222);
        AddL("Папка вложений:", lx + 232, y, 222); y += 20;
        txInbox  = AddT(s.Inbox ?? "", lx, y, 220);
        txAttach = AddT(s.Attachments ?? "Serv\\Attachments", lx + 232, y, 220); y += 34;

        AddL("Свойство даты:", lx, y, 200);
        AddL("Формат даты:", lx + 232, y, 200); y += 20;
        txDateProp = AddT(s.DatePropName ?? "date", lx, y, 200);
        txDate     = AddT(s.DateFormat ?? "yyyy-MM-dd", lx + 232, y, 200);
        AddLG("стандарт: date", lx + 210, y + 3, 18); y += 34;

        AddL("Свойства заметки:", lx, y, rw); y += 20;
        dgvProps = MakeGrid(lx, y, rw, s.Props);
        Controls.Add(dgvProps);
        AddLG("Редактируйте прямо в таблице. Delete на выбранной строке — удаление.", lx, y + 118, rw);
        y += 138;

        AddL("Шаблон Templater (оставьте пустым, если не нужен):", lx, y, rw); y += 20;
        txTmpl = AddT(s.TemplaterCmd ?? "", lx, y, rw);
        AddLG("напр.: templater-obsidian:Folder/Template.md", lx, y + 26, rw); y += 52;

        var grp = new GroupBox { Text = "Горячая клавиша клиппера", Location = new Point(lx, y), Size = new Size(rw, 64) };
        ckCtrl  = new CheckBox { Text = "Ctrl",  Location = new Point(10,  28), AutoSize = true, Checked = s.HotkeyCtrl  };
        ckAlt   = new CheckBox { Text = "Alt",   Location = new Point(78,  28), AutoSize = true, Checked = s.HotkeyAlt   };
        ckShift = new CheckBox { Text = "Shift", Location = new Point(142, 28), AutoSize = true, Checked = s.HotkeyShift };
        cbKey   = new ComboBox { Location = new Point(220, 24), Size = new Size(86, 24),
                      DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (string kn in AppSettings.KEY_NAMES) cbKey.Items.Add(kn);
        int sel = Array.IndexOf(AppSettings.KEY_VKS, s.HotkeyVk);
        cbKey.SelectedIndex = (sel >= 0) ? sel : 7;
        grp.Controls.AddRange(new Control[] { ckCtrl, ckAlt, ckShift, cbKey });
        Controls.Add(grp); y += 76;

        var btnOk     = new Button { Text = "Сохранить", Location = new Point(rw - 176, y), Size = new Size(110, 30) };
        var btnCancel = new Button { Text = "Отмена",    Location = new Point(rw - 58,  y), Size = new Size(70,  30),
                            DialogResult = DialogResult.Cancel };
        Controls.Add(btnOk); Controls.Add(btnCancel);
        AcceptButton = btnOk; CancelButton = btnCancel;

        AppSettings cur = s;
        btnOk.Click += delegate {
            if (string.IsNullOrWhiteSpace(txVault.Text)) {
                MessageBox.Show("Укажите путь к хранилищу.", "Ошибка",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            Result = Clone(cur);
            Result.VaultPath    = txVault.Text.TrimEnd('\\', '/');
            Result.Inbox        = txInbox.Text.Trim();
            Result.Attachments  = txAttach.Text.Trim();
            Result.DatePropName = string.IsNullOrWhiteSpace(txDateProp.Text) ? "date" : txDateProp.Text.Trim();
            Result.DateFormat   = string.IsNullOrWhiteSpace(txDate.Text) ? "yyyy-MM-dd" : txDate.Text.Trim();
            Result.TemplaterCmd = txTmpl.Text.Trim();
            Result.HotkeyCtrl   = ckCtrl.Checked;
            Result.HotkeyAlt    = ckAlt.Checked;
            Result.HotkeyShift  = ckShift.Checked;
            Result.HotkeyVk     = (cbKey.SelectedIndex >= 0) ? AppSettings.KEY_VKS[cbKey.SelectedIndex] : 0x77u;
            Result.Props        = ReadGrid(dgvProps);
            DialogResult = DialogResult.OK;
        };
    }

    // Копия настроек: правим только свою половину, чужая переносится как есть
    public static AppSettings Clone(AppSettings s) {
        var r = new AppSettings(s.SettingsPath);
        r.VaultPath = s.VaultPath; r.Inbox = s.Inbox; r.Attachments = s.Attachments;
        r.DatePropName = s.DatePropName; r.DateFormat = s.DateFormat;
        r.TemplaterCmd = s.TemplaterCmd; r.Props = new List<string[]>(s.Props);
        r.HotkeyCtrl = s.HotkeyCtrl; r.HotkeyAlt = s.HotkeyAlt;
        r.HotkeyShift = s.HotkeyShift; r.HotkeyVk = s.HotkeyVk;
        r.CapFolder = s.CapFolder; r.CapFileName = s.CapFileName;
        r.CapHeader = s.CapHeader;
        r.NavSource = s.NavSource; r.NavTarget = s.NavTarget;
        r.CapEntry = s.CapEntry; r.CapSeparator = s.CapSeparator;
        r.CapProps = new List<string[]>(s.CapProps);
        r.CapHkCtrl = s.CapHkCtrl; r.CapHkAlt = s.CapHkAlt; r.CapHkShift = s.CapHkShift;
        r.CapHkVk = s.CapHkVk; r.CapHkBare = s.CapHkBare;
        r.CapTheme = s.CapTheme; r.CapFont = s.CapFont;
        r.CapFontSize = s.CapFontSize; r.CapFlash = s.CapFlash;
        r.CapW = s.CapW; r.CapH = s.CapH; r.CapX = s.CapX; r.CapY = s.CapY;
        return r;
    }

    public static DataGridView MakeGrid(int x, int y, int w, List<string[]> rows) {
        var g = new DataGridView();
        g.Location = new Point(x, y);
        g.Size     = new Size(w, 114);
        g.RowHeadersVisible = false;
        g.AllowUserToAddRows    = true;
        g.AllowUserToDeleteRows = true;
        g.AllowUserToResizeRows = false;
        g.ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.DisableResizing;
        g.ColumnHeadersHeight = 24;
        g.ScrollBars = ScrollBars.Vertical;
        g.Columns.Add(new DataGridViewTextBoxColumn { Name = "n", HeaderText = "Свойство", Width = 160 });
        g.Columns.Add(new DataGridViewTextBoxColumn { Name = "v", HeaderText = "Значение",
            AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill });
        foreach (string[] p in rows) if (p.Length >= 2) g.Rows.Add(p[0], p[1]);
        return g;
    }
    public static List<string[]> ReadGrid(DataGridView g) {
        var list = new List<string[]>();
        foreach (DataGridViewRow row in g.Rows) {
            if (row.IsNewRow) continue;
            string pn = (row.Cells["n"].Value as string ?? "").Trim();
            string pv = (row.Cells["v"].Value as string ?? "").Trim();
            if (!string.IsNullOrEmpty(pn)) list.Add(new string[] { pn, pv });
        }
        return list;
    }

    protected override void OnLoad(EventArgs e) { base.OnLoad(e); Activate(); }

    void AddL(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y),
            Size = new Size(w, 18), AutoSize = false });
    }
    void AddLG(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y),
            Size = new Size(w, 18), AutoSize = false, ForeColor = SystemColors.GrayText });
    }
    TextBox AddT(string text, int x, int y, int w) {
        var tb = new TextBox { Text = text, Location = new Point(x, y), Size = new Size(w, 22) };
        Controls.Add(tb); return tb;
    }
}

// ════════════════════════════════════════════════════════════
// Окно настроек капчи
// ════════════════════════════════════════════════════════════
public class CaptureSettingsForm : Form {
    public AppSettings Result;
    TextBox txFolder, txFile, txHeader, txEntry, txSep, txFont;
    NumericUpDown numSize, numFlash;
    ComboBox cbTheme, cbBare, cbKey;
    CheckBox ckCtrl, ckAlt, ckShift;
    DataGridView dgv;

    public CaptureSettingsForm(AppSettings s) {
        Text = "Настройки быстрых заметок";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition   = FormStartPosition.CenterScreen;
        ClientSize      = new Size(488, 668);
        MaximizeBox = false; MinimizeBox = false;
        TopMost = true;

        int lx = 12, rw = 464, y = 12;

        AddL("Папка-накопитель (внутри хранилища или полный путь):", lx, y, rw); y += 20;
        txFolder = AddT(s.CapFolder ?? "", lx, y, rw); y += 34;

        AddL("Шаблон имени файла:", lx, y, rw); y += 20;
        txFile = AddT(s.CapFileName ?? "", lx, y, rw);
        AddLG("{date:ФОРМАТ} — дата; подпапки допустимы: {date:yyyy}\\\\{date:MM}.md", lx, y + 26, rw);
        y += 52;

        AddL("Строка при создании файла:", lx, y, rw); y += 20;
        txHeader = AddT(s.CapHeader ?? "", lx, y, rw);
        AddLG("Пишется один раз, при создании файла. Пусто — ничего не добавляется.", lx, y + 26, rw);
        y += 52;

        AddL("Шаблон записи:", lx, y, 222);
        AddL("Разделитель записей:", lx + 232, y, 222); y += 20;
        txEntry = AddT(s.CapEntry ?? "", lx, y, 220);
        txSep   = AddT((s.CapSeparator ?? "").Replace("\n","\\n"), lx + 232, y, 220);
        AddLG("{clock} — часы, {text} — текст", lx, y + 24, 220);
        AddLG("\\n\\n — пустая строка между записями", lx + 232, y + 24, 220);
        y += 50;

        AddL("Свойства заметки (пишутся при создании файла):", lx, y, rw); y += 20;
        dgv = SettingsForm.MakeGrid(lx, y, rw, s.CapProps);
        Controls.Add(dgv);
        AddLG("Значения принимают {date:ФОРМАТ}. Delete — удаление строки.", lx, y + 118, rw);
        y += 138;

        var grpHk = new GroupBox { Text = "Горячая клавиша заметки", Location = new Point(lx, y), Size = new Size(rw, 92) };
        var lbBare = new Label { Text = "Одиночный модификатор:", Location = new Point(10, 24),
                          Size = new Size(150, 18) };
        cbBare = new ComboBox { Location = new Point(166, 20), Size = new Size(150, 24),
                          DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (string bn in AppSettings.BARE_NAMES) cbBare.Items.Add(bn);
        cbBare.SelectedIndex = (s.CapHkBare >= 0 && s.CapHkBare < AppSettings.BARE_NAMES.Length) ? s.CapHkBare : 0;

        ckCtrl  = new CheckBox { Text = "Ctrl",  Location = new Point(10,  58), AutoSize = true, Checked = s.CapHkCtrl  };
        ckAlt   = new CheckBox { Text = "Alt",   Location = new Point(78,  58), AutoSize = true, Checked = s.CapHkAlt   };
        ckShift = new CheckBox { Text = "Shift", Location = new Point(142, 58), AutoSize = true, Checked = s.CapHkShift };
        cbKey   = new ComboBox { Location = new Point(220, 54), Size = new Size(86, 24),
                          DropDownStyle = ComboBoxStyle.DropDownList };
        cbKey.Items.Add("—");
        foreach (string kn in AppSettings.KEY_NAMES) cbKey.Items.Add(kn);
        int ksel = Array.IndexOf(AppSettings.KEY_VKS, s.CapHkVk);
        cbKey.SelectedIndex = (ksel >= 0) ? ksel + 1 : 0;

        var lbHint = new Label { Text = "Заполнен одиночный — сочетание ниже не используется",
                          Location = new Point(324, 24), Size = new Size(130, 34),
                          ForeColor = SystemColors.GrayText };
        grpHk.Controls.AddRange(new Control[] { lbBare, cbBare, lbHint, ckCtrl, ckAlt, ckShift, cbKey });
        Controls.Add(grpHk); y += 104;

        var grpV = new GroupBox { Text = "Вид окошка", Location = new Point(lx, y), Size = new Size(rw, 92) };
        var lbTheme = new Label { Text = "Тема:", Location = new Point(10, 26), Size = new Size(46, 18) };
        cbTheme = new ComboBox { Location = new Point(58, 22), Size = new Size(110, 24),
                          DropDownStyle = ComboBoxStyle.DropDownList };
        cbTheme.Items.Add("светлая"); cbTheme.Items.Add("тёмная");
        cbTheme.SelectedIndex = (s.CapTheme == "dark") ? 1 : 0;

        var lbFlash = new Label { Text = "Миганий при появлении:", Location = new Point(194, 26), Size = new Size(146, 18) };
        numFlash = new NumericUpDown { Location = new Point(344, 22), Size = new Size(60, 24),
                          Minimum = 0, Maximum = 20, Value = Math.Max(0, Math.Min(20, s.CapFlash)) };

        var lbFont = new Label { Text = "Шрифт:", Location = new Point(10, 58), Size = new Size(46, 18) };
        txFont  = new TextBox { Text = s.CapFont ?? "Segoe UI", Location = new Point(58, 55), Size = new Size(110, 22) };
        var lbSize = new Label { Text = "Размер:", Location = new Point(194, 58), Size = new Size(52, 18) };
        numSize = new NumericUpDown { Location = new Point(250, 55), Size = new Size(60, 24),
                          Minimum = 7, Maximum = 48, Value = Math.Max(7, Math.Min(48, s.CapFontSize)) };
        var lbZero = new Label { Text = "0 — без мигания", Location = new Point(344, 58), Size = new Size(110, 18),
                          ForeColor = SystemColors.GrayText };
        grpV.Controls.AddRange(new Control[] { lbTheme, cbTheme, lbFlash, numFlash,
                                              lbFont, txFont, lbSize, numSize, lbZero });
        Controls.Add(grpV); y += 104;

        var btnOk     = new Button { Text = "Сохранить", Location = new Point(rw - 176, y), Size = new Size(110, 30) };
        var btnCancel = new Button { Text = "Отмена",    Location = new Point(rw - 58,  y), Size = new Size(70,  30),
                            DialogResult = DialogResult.Cancel };
        Controls.Add(btnOk); Controls.Add(btnCancel);
        AcceptButton = btnOk; CancelButton = btnCancel;

        AppSettings cur = s;
        btnOk.Click += delegate {
            if (string.IsNullOrWhiteSpace(txFile.Text)) {
                MessageBox.Show("Укажите шаблон имени файла.", "Ошибка",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            Result = SettingsForm.Clone(cur);
            Result.CapFolder    = txFolder.Text.Trim();
            Result.CapFileName  = txFile.Text.Trim();
            Result.CapHeader    = txHeader.Text;
            Result.CapEntry     = txEntry.Text;
            Result.CapSeparator = txSep.Text.Replace("\\n", "\n");
            Result.CapProps     = SettingsForm.ReadGrid(dgv);
            Result.CapHkBare    = cbBare.SelectedIndex;
            Result.CapHkCtrl    = ckCtrl.Checked;
            Result.CapHkAlt     = ckAlt.Checked;
            Result.CapHkShift   = ckShift.Checked;
            Result.CapHkVk      = (cbKey.SelectedIndex > 0) ? AppSettings.KEY_VKS[cbKey.SelectedIndex - 1] : 0u;
            Result.CapTheme     = (cbTheme.SelectedIndex == 1) ? "dark" : "light";
            Result.CapFont      = string.IsNullOrWhiteSpace(txFont.Text) ? "Segoe UI" : txFont.Text.Trim();
            Result.CapFontSize  = (int)numSize.Value;
            Result.CapFlash     = (int)numFlash.Value;
            DialogResult = DialogResult.OK;
        };
    }

    protected override void OnLoad(EventArgs e) { base.OnLoad(e); Activate(); }

    void AddL(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y),
            Size = new Size(w, 18), AutoSize = false });
    }
    void AddLG(string t, int x, int y, int w) {
        Controls.Add(new Label { Text = t, Location = new Point(x, y),
            Size = new Size(w, 18), AutoSize = false, ForeColor = SystemColors.GrayText });
    }
    TextBox AddT(string text, int x, int y, int w) {
        var tb = new TextBox { Text = text, Location = new Point(x, y), Size = new Size(w, 22) };
        Controls.Add(tb); return tb;
    }
}

// ════════════════════════════════════════════════════════════
// Попап клиппера (закрывается через 10 сек)
// ════════════════════════════════════════════════════════════
public class NotePopup : Form {
    public NotePopup(string noteFile, string goUri) {
        int w = 330, h = 100;
        this.Text = "Obsiclipcapture";
        this.FormBorderStyle = FormBorderStyle.FixedToolWindow;
        this.StartPosition   = FormStartPosition.Manual;
        this.Size            = new Size(w, h);
        this.TopMost         = true;
        this.ShowInTaskbar   = false;
        Rectangle wa  = Screen.PrimaryScreen.WorkingArea;
        this.Location = new Point(wa.Right - w - 12, wa.Bottom - h - 12);
        Label lbl = new Label { Text = noteFile, Location = new Point(8, 10),
                        Size = new Size(308, 20), AutoEllipsis = true };
        string uri = goUri;
        Button btnGo = new Button { Text = "Перейти в заметку",
                           Location = new Point(8, 40), Size = new Size(148, 26) };
        btnGo.Click += delegate { try { Process.Start(uri); } catch {} this.Close(); };
        Button btnX  = new Button { Text = "Закрыть",
                           Location = new Point(164, 40), Size = new Size(76, 26) };
        btnX.Click  += delegate { this.Close(); };
        this.Controls.AddRange(new Control[] { lbl, btnGo, btnX });
        Timer t = new Timer { Interval = 10000 };
        t.Tick += delegate { t.Stop(); t.Dispose(); this.Close(); };
        t.Start();
    }
}

// ════════════════════════════════════════════════════════════
// Окошко быстрой заметки
// ════════════════════════════════════════════════════════════
public class CaptureForm : Form {

    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)]
    struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }
    [DllImport("user32.dll")] static extern bool FlashWindowEx(ref FLASHWINFO pwfi);

    public static string Draft = "";

    AppSettings st;
    TextBox box;
    bool saved;
    public string SavedPath;

    public CaptureForm(AppSettings s) {
        st = s;

        Color bg, fg, bx;
        if (st.CapTheme == "dark") {
            bg = Color.FromArgb(30, 30, 32);
            fg = Color.FromArgb(224, 224, 224);
            bx = Color.FromArgb(38, 38, 41);
        } else {
            bg = Color.FromArgb(250, 250, 248);
            fg = Color.FromArgb(26, 26, 26);
            bx = Color.White;
        }

        Text            = "Заметка";
        FormBorderStyle = FormBorderStyle.Sizable;
        ShowInTaskbar   = false;
        TopMost         = true;
        MinimizeBox     = false;
        MaximizeBox     = false;
        BackColor       = bg;
        ClientSize      = new Size(Math.Max(200, st.CapW), Math.Max(100, st.CapH));
        if (st.CapX >= 0 && st.CapY >= 0) {
            StartPosition = FormStartPosition.Manual;
            Location      = new Point(st.CapX, st.CapY);
        } else {
            StartPosition = FormStartPosition.CenterScreen;
        }

        box = new TextBox();
        box.Multiline   = true;
        box.AcceptsTab  = true;
        box.ScrollBars  = ScrollBars.Vertical;
        box.BorderStyle = BorderStyle.None;
        box.Dock        = DockStyle.Fill;
        box.BackColor   = bx;
        box.ForeColor   = fg;
        try { box.Font = new Font(st.CapFont ?? "Segoe UI", st.CapFontSize); }
        catch { box.Font = new Font("Segoe UI", 11); }
        box.Text = Draft;
        box.SelectionStart = box.TextLength;
        box.KeyDown += OnBoxKey;

        var pad = new Panel();
        pad.Dock      = DockStyle.Fill;
        pad.Padding   = new Padding(10);
        pad.BackColor = bx;
        pad.Controls.Add(box);
        Controls.Add(pad);
    }

    void OnBoxKey(object sender, KeyEventArgs e) {
        // Ctrl+Enter — сохранить и закрыть
        if (e.KeyCode == Keys.Enter && e.Control && !e.Shift && !e.Alt) {
            e.SuppressKeyPress = true;
            if (box.Text.Trim().Length > 0) { SaveNote(); }
            Draft = "";
            saved = true;
            Close();
            return;
        }
        // Escape — закрыть, текст остаётся черновиком
        if (e.KeyCode == Keys.Escape) {
            e.SuppressKeyPress = true;
            Close();
        }
    }

    string ResolveFolder() {
        string f = st.CapFolder ?? "";
        if (f.Length == 0) return st.VaultPath;
        if (f.Contains(":") || f.StartsWith("\\\\")) return f;
        return Path.Combine(st.VaultPath ?? "", f);
    }

    void SaveNote() {
        Nav.Ensure(st);
        DateTime now = DateTime.Now;
        string dir  = ResolveFolder();
        string rel  = AppSettings.Expand(st.CapFileName ?? "note.md", now, null);
        string path = Path.Combine(dir, rel);
        string pdir = Path.GetDirectoryName(path);
        if (!Directory.Exists(pdir)) Directory.CreateDirectory(pdir);

        string entry = AppSettings.Expand(st.CapEntry ?? "{text}", now, box.Text.Trim());
        var enc = new UTF8Encoding(false);
        string outText;

        if (File.Exists(path)) {
            string old = File.ReadAllText(path, enc).TrimEnd('\r', '\n');
            outText = old + (st.CapSeparator ?? "\n\n") + entry + "\n";
        } else {
            string fm = "";
            if (st.CapProps != null && st.CapProps.Count > 0) {
                fm = "---\n";
                foreach (string[] p in st.CapProps)
                    if (p.Length >= 1 && !string.IsNullOrEmpty(p[0]))
                        fm += p[0] + ": " + AppSettings.Expand(p.Length > 1 ? p[1] : "", now, null) + "\n";
                fm += "---\n\n";
            }
            string hdr = "";
            if (!string.IsNullOrEmpty(st.CapHeader))
                hdr = st.CapHeader + "\n\n";
            outText = fm + hdr + entry + "\n";
        }
        File.WriteAllText(path, outText, enc);
        SavedPath = path;
    }

    protected override void OnShown(EventArgs e) {
        base.OnShown(e);
        Activate();
        try { SetForegroundWindow(Handle); } catch {}
        box.Focus();

        int n = st.CapFlash;
        try {
            var fi = new FLASHWINFO();
            fi.cbSize    = (uint)Marshal.SizeOf(typeof(FLASHWINFO));
            fi.hwnd      = Handle;
            fi.uCount    = (uint)Math.Max(0, n);
            fi.dwTimeout = 0;
            fi.dwFlags   = (n > 0) ? 2u : 0u;   // FLASHW_CAPTION : FLASHW_STOP
            FlashWindowEx(ref fi);
        } catch {}
    }

    protected override void OnFormClosing(FormClosingEventArgs e) {
        if (!saved) Draft = box.Text;
        st.CapW = ClientSize.Width;
        st.CapH = ClientSize.Height;
        st.CapX = Location.X;
        st.CapY = Location.Y;
        try { st.Save(); } catch {}
        base.OnFormClosing(e);
    }
}

// ════════════════════════════════════════════════════════════
// Основная форма — носитель хоткеев и трея
// ════════════════════════════════════════════════════════════
public class MainForm : Form {

    [DllImport("user32.dll")] static extern bool  RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
    [DllImport("user32.dll")] static extern bool  UnregisterHotKey(IntPtr h, int id);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint  GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);

    [DllImport("user32.dll")] static extern short GetKeyState(int nVirtKey);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int nVirtKey);
    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    const int    WM_HOTKEY        = 0x0312;
    const int    HK_CLIP          = 1;
    const int    HK_CAP           = 2;
    const uint   KEYEVENTF_KEYUP  = 0x0002;
    const byte   VK_CONTROL       = 0x11;
    const byte   VK_C             = 0x43;
    const byte   VK_L             = 0x4C;
    const byte   VK_A             = 0x41;
    const byte   VK_ESCAPE        = 0x1B;

    readonly string[] BROWSERS = { "chrome","firefox","msedge","opera","brave","vivaldi" };
    AppSettings  settings;
    NotifyIcon   tray;
    bool         busy;
    bool         firstRun;
    Timer        poll;
    bool         bareHeld;
    CaptureForm  capForm;

    bool IsKeyDown(int vk) { return (GetKeyState(vk) & 0x8000) != 0; }
    void KbDown(byte vk)   { keybd_event(vk, 0, 0, UIntPtr.Zero); }
    void KbUp(byte vk)     { keybd_event(vk, 0, KEYEVENTF_KEYUP, UIntPtr.Zero); }

    void PressCtrl(byte vk) {
        KbDown(VK_CONTROL); KbDown(vk);
        System.Threading.Thread.Sleep(30);
        KbUp(vk); KbUp(VK_CONTROL);
        System.Threading.Thread.Sleep(30);
    }
    void PressKey(byte vk) {
        KbDown(vk);
        System.Threading.Thread.Sleep(30);
        KbUp(vk);
    }

    void WaitModifiersUp() {
        for (int i = 0; i < 30; i++) {
            if (!IsKeyDown(0x10) && !IsKeyDown(0x11) && !IsKeyDown(0x12)) break;
            System.Threading.Thread.Sleep(50);
        }
        System.Threading.Thread.Sleep(80);
    }

    public MainForm(string settingsPath) {
        ShowInTaskbar = false;
        WindowState   = FormWindowState.Minimized;
        Opacity       = 0;

        settings = new AppSettings(settingsPath);
        firstRun = !settings.Load();

        tray = new NotifyIcon { Icon = SystemIcons.Information, Visible = true };
        var menu = new ContextMenuStrip();
        menu.Items.Add("Новая заметка", null, delegate { ShowCapture(); });
        menu.Items.Add("-");
        menu.Items.Add("Восстановить шапку навигации", null, delegate { RestoreNav(); });
        menu.Items.Add("-");
        menu.Items.Add("Настройки клиппера", null, delegate { OpenSettings(); });
        menu.Items.Add("Настройки заметок",  null, delegate { OpenCapSettings(); });
        menu.Items.Add("-");
        menu.Items.Add("Выход", null, delegate { Application.Exit(); });
        tray.ContextMenuStrip = menu;
        tray.MouseClick += delegate(object sender, MouseEventArgs e) {
            if (e.Button == MouseButtons.Left) ShowCapture();
        };

        Application.ThreadException += delegate(object sender,
                System.Threading.ThreadExceptionEventArgs e) {
            try { tray.ShowBalloonTip(6000, "Obsiclipcapture", e.Exception.Message, ToolTipIcon.Error); }
            catch {}
        };

        poll = new Timer { Interval = 40 };
        poll.Tick += OnPoll;

        if (!firstRun) { Nav.Ensure(settings); RegisterHotkeys(); UpdateTrayText(); }
        else tray.Text = "Obsiclipcapture — настройка...";
    }

    protected override void OnLoad(EventArgs e) {
        base.OnLoad(e);
        if (!firstRun) return;
        try { OpenSettings(); }
        catch (Exception ex) {
            try { tray.ShowBalloonTip(8000, "Obsiclipcapture", ex.Message, ToolTipIcon.Error); } catch {}
        }
        if (string.IsNullOrEmpty(settings.VaultPath)) { Application.Exit(); return; }
        Nav.Ensure(settings);
        RegisterHotkeys(); UpdateTrayText(); firstRun = false;
    }

    void RegisterHotkeys() {
        bool ok = RegisterHotKey(Handle, HK_CLIP, settings.GetMod(), settings.HotkeyVk);
        if (!ok) try { tray.ShowBalloonTip(6000, "Obsiclipcapture",
            "Не удалось зарегистрировать [" + settings.GetHotkeyDisplay() +
            "] для клиппера. Сочетание занято другим приложением.", ToolTipIcon.Warning); } catch {}

        // Одиночный модификатор через RegisterHotKey недоступен — для него опрос
        if (settings.CapUsesBare()) {
            poll.Start();
        } else {
            poll.Stop();
            if (settings.CapUsesRegistered()) {
                bool ok2 = RegisterHotKey(Handle, HK_CAP, settings.GetCapMod(), settings.CapHkVk);
                if (!ok2) try { tray.ShowBalloonTip(6000, "Obsiclipcapture",
                    "Не удалось зарегистрировать [" + settings.GetCapHotkeyDisplay() +
                    "] для заметок. Сочетание занято другим приложением.", ToolTipIcon.Warning); } catch {}
            }
        }
    }

    void UnregisterHotkeys() {
        try { UnregisterHotKey(Handle, HK_CLIP); } catch {}
        try { UnregisterHotKey(Handle, HK_CAP);  } catch {}
        try { poll.Stop(); } catch {}
    }

    void UpdateTrayText() {
        try {
            tray.Text = "Obsiclipcapture  клип [" + settings.GetHotkeyDisplay()
                      + "]  заметка [" + settings.GetCapHotkeyDisplay() + "]";
        } catch {}
    }

    void RestoreNav() {
        bool written = Nav.Ensure(settings);
        string msg;
        if (Nav.LastError.Length > 0)      msg = "Не удалось: " + Nav.LastError;
        else if (written)                  msg = "Служебная заметка навигации записана заново.";
        else if (Nav.TargetPath(settings) == null) msg = "Навигация отключена: пуст ключ nav_target или путь к хранилищу.";
        else                               msg = "Служебная заметка на месте и совпадает с оригиналом.";
        try { tray.ShowBalloonTip(5000, "Obsiclipcapture", msg,
              Nav.LastError.Length > 0 ? ToolTipIcon.Warning : ToolTipIcon.Info); } catch {}
    }

    void OpenSettings() {
        using (SettingsForm form = new SettingsForm(settings)) {
            if (form.ShowDialog() != DialogResult.OK || form.Result == null) return;
            settings = form.Result;
            settings.Save();
            Nav.Ensure(settings);
            UnregisterHotkeys(); RegisterHotkeys(); UpdateTrayText();
        }
    }

    void OpenCapSettings() {
        if (string.IsNullOrEmpty(settings.VaultPath)) {
            try { tray.ShowBalloonTip(4000, "Obsiclipcapture",
                "Сначала укажите путь к хранилищу в настройках клиппера.", ToolTipIcon.Warning); } catch {}
            return;
        }
        using (CaptureSettingsForm form = new CaptureSettingsForm(settings)) {
            if (form.ShowDialog() != DialogResult.OK || form.Result == null) return;
            settings = form.Result;
            settings.Save();
            Nav.Ensure(settings);
            UnregisterHotkeys(); RegisterHotkeys(); UpdateTrayText();
        }
    }

    void OnPoll(object sender, EventArgs e) {
        if (!settings.CapUsesBare()) return;
        int vk = AppSettings.BARE_VKS[settings.CapHkBare];
        bool down = (GetAsyncKeyState(vk) & 0x8000) != 0;
        if (down && !bareHeld) { bareHeld = true; ShowCapture(); }
        else if (!down) bareHeld = false;
    }

    void ShowCapture() {
        if (string.IsNullOrEmpty(settings.VaultPath)) {
            try { tray.ShowBalloonTip(4000, "Obsiclipcapture",
                "Путь к хранилищу не задан. Откройте настройки.", ToolTipIcon.Warning); } catch {}
            return;
        }
        if (capForm != null && !capForm.IsDisposed) {
            try { capForm.Activate(); } catch {}
            return;
        }
        try {
            capForm = new CaptureForm(settings);
            capForm.FormClosed += delegate { capForm = null; };
            capForm.Show();
        } catch (Exception ex) {
            try { tray.ShowBalloonTip(6000, "Obsiclipcapture", ex.Message, ToolTipIcon.Error); } catch {}
        }
    }

    bool IsBrowser(string p) {
        p = p.ToLower();
        foreach (var b in BROWSERS) if (p.Contains(b)) return true;
        return false;
    }

    string SafeName(string s) {
        if (string.IsNullOrWhiteSpace(s)) return "";
        int i = s.IndexOfAny(new[] { '\n', '\r' });
        if (i >= 0) s = s.Substring(0, i);
        foreach (char c in Path.GetInvalidFileNameChars()) s = s.Replace(c.ToString(), "");
        s = s.Trim();
        return s.Length > 80 ? s.Substring(0, 80) : s;
    }

    string SafeGetText() {
        for (int i = 0; i < 6; i++) {
            try { return Clipboard.GetText() ?? ""; } catch {}
            System.Threading.Thread.Sleep(80);
        }
        return "";
    }
    void SafeSetText(string t) {
        if (string.IsNullOrEmpty(t)) return;
        for (int i = 0; i < 5; i++) {
            try { Clipboard.SetText(t); return; } catch {}
            System.Threading.Thread.Sleep(50);
        }
    }
    void SafeClear() {
        for (int i = 0; i < 5; i++) {
            try { Clipboard.Clear(); return; } catch {}
            System.Threading.Thread.Sleep(50);
        }
    }
    void RestoreClipboard(string prev) {
        if (string.IsNullOrEmpty(prev)) SafeClear(); else SafeSetText(prev);
    }

    void DoClip(IntPtr hwnd) {
        if (busy) return;
        busy = true;
        try {
            if (string.IsNullOrEmpty(settings.VaultPath)) {
                try { tray.ShowBalloonTip(4000, "Obsiclipcapture",
                    "Путь к хранилищу не задан. Откройте Настройки.", ToolTipIcon.Warning); } catch {}
                return;
            }

            // Если Ctrl/Alt ещё удерживаются, SendInput послал бы Ctrl+Alt+C
            // вместо Ctrl+C, и буфер остался бы пустым.
            WaitModifiersUp();

            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            string proc = "";
            try { proc = Process.GetProcessById((int)pid).ProcessName; } catch {}
            var sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, 512);
            string title = sb.ToString();

            string created  = DateTime.Now.ToString(settings.DateFormat ?? "yyyy-MM-dd");
            string ts       = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
            string prevText = SafeGetText();

            // ── 1. Копируем выделение ────────────────────────────────
            SafeClear();
            PressCtrl(VK_C);
            System.Threading.Thread.Sleep(500);
            string txt = SafeGetText();
            Image  img = null;
            try { img = Clipboard.GetImage(); } catch {}

            // ── 2. Source ────────────────────────────────────────────
            string source = "";
            if (IsBrowser(proc)) {
                try {
                    SafeClear();
                    PressCtrl(VK_L);
                    System.Threading.Thread.Sleep(250);
                    PressCtrl(VK_A);
                    System.Threading.Thread.Sleep(60);
                    PressCtrl(VK_C);
                    System.Threading.Thread.Sleep(300);
                    source = SafeGetText();
                    PressKey(VK_ESCAPE);
                    System.Threading.Thread.Sleep(150);
                } catch {}
            } else if (proc.ToLower().Contains("telegram")) {
                source = "Telegram: " + title
                    .Replace(" \u2014 Telegram Desktop", "")
                    .Replace("Telegram Desktop", "").Trim();
            } else {
                source = title;
            }
            source = source.Replace("\r", "").Replace("\n", " ").Replace("\"", "'");

            // ── 3. Изображение ───────────────────────────────────────
            string imgEmbed = "";
            if (string.IsNullOrEmpty(txt) && img != null) {
                try {
                    string attDir = Path.Combine(settings.VaultPath,
                        settings.Attachments ?? "Attachments");
                    if (!Directory.Exists(attDir)) Directory.CreateDirectory(attDir);
                    string imgFile = "clip-" + ts + ".png";
                    img.Save(Path.Combine(attDir, imgFile), ImageFormat.Png);
                    imgEmbed = "![[" + (settings.Attachments ?? "Attachments").Replace('\\', '/')
                             + "/" + imgFile + "]]";
                } catch {}
            }

            if (string.IsNullOrEmpty(txt) && string.IsNullOrEmpty(imgEmbed)) {
                RestoreClipboard(prevText); return;
            }

            string name = SafeName(txt);
            if (string.IsNullOrEmpty(name)) name = "Clipped " + ts;

            string dir = string.IsNullOrEmpty(settings.Inbox)
                ? settings.VaultPath
                : Path.Combine(settings.VaultPath, settings.Inbox);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

            string path = Path.Combine(dir, name + ".md");
            if (File.Exists(path)) path = Path.Combine(dir, name + " " + ts + ".md");

            string body      = string.IsNullOrEmpty(imgEmbed) ? txt : imgEmbed;
            string dateProp  = settings.DatePropName ?? "date";
            string extraProps = "";
            foreach (string[] p in settings.Props)
                if (p.Length >= 1 && !string.IsNullOrEmpty(p[0]))
                    extraProps += "\n" + p[0] + ": " + (p.Length > 1 ? p[1] : "");

            string note = "---\nsource: \"" + source + "\"\n" + dateProp + ": " + created
                        + extraProps + "\n---\n\n" + body + "\n";

            File.WriteAllText(path, note, Encoding.UTF8);
            RestoreClipboard(prevText);

            string vaultName = Path.GetFileName(settings.VaultPath.TrimEnd('\\', '/'));
            string relPath   = path.Substring(settings.VaultPath.Length)
                                   .TrimStart('\\', '/').Replace('\\', '/');

            if (!string.IsNullOrEmpty(settings.TemplaterCmd)) {
                try {
                    string advUri = "obsidian://advanced-uri?vault=" + Uri.EscapeDataString(vaultName)
                                  + "&filepath=" + Uri.EscapeDataString(relPath)
                                  + "&commandid=" + Uri.EscapeDataString(settings.TemplaterCmd);
                    Process.Start(advUri);
                } catch {}
            }

            try {
                string obsUri = "obsidian://open?vault=" + Uri.EscapeDataString(vaultName)
                              + "&file=" + Uri.EscapeDataString(relPath);
                new NotePopup(Path.GetFileName(path), obsUri).Show();
            } catch {
                try { tray.ShowBalloonTip(3000, "OK", Path.GetFileName(path), ToolTipIcon.Info); } catch {}
            }
        }
        catch (Exception ex) {
            try { tray.ShowBalloonTip(6000, "Obsiclipcapture", ex.Message, ToolTipIcon.Error); } catch {}
        }
        finally { busy = false; }
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY) {
            int id = m.WParam.ToInt32();
            if (id == HK_CLIP) {
                IntPtr hwnd = GetForegroundWindow();
                BeginInvoke(new Action(() => DoClip(hwnd)));
            } else if (id == HK_CAP) {
                BeginInvoke(new Action(() => ShowCapture()));
            }
        }
        base.WndProc(ref m);
    }

    protected override void OnFormClosing(FormClosingEventArgs e) {
        UnregisterHotkeys();
        try { tray.Visible = false; tray.Dispose(); } catch {}
        base.OnFormClosing(e);
    }
}
'@ -ReferencedAssemblies "System.Windows.Forms","System.Drawing" -ErrorAction Stop
    Write-Log "Add-Type OK"
} catch {
    Write-Log "FATAL Add-Type: $_"
    [System.Windows.Forms.MessageBox]::Show(
        "Ошибка компиляции:`n`n" + $_.Exception.Message + "`n`nПодробности: $LogFile",
        "Obsiclipcapture — Ошибка запуска")
    exit 1
}

Write-Log "Application.Run"
try {
    [System.Windows.Forms.Application]::Run((New-Object MainForm($SettingsFile)))
} catch {
    Write-Log "FATAL Run: $_"
    [System.Windows.Forms.MessageBox]::Show("Ошибка запуска:`n`n" + $_.Exception.Message,
        "Obsiclipcapture — Ошибка")
}
Write-Log "=== EXIT"
