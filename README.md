# Codex Remote VPS Multi-Account Skill

[English](#english) | [فارسی](#فارسی)

<a id="english"></a>

## English

A reusable skill and deployment toolkit for managing **Codex Desktop SSH Remote connections** across multiple VPS hosts and multiple ChatGPT/API authentication profiles.

The core rule of this project is simple:

> **Authentication switching and model selection are separate concerns.**

The auth manager may switch the active account, clear a stale model pin left by the previous account, and restart the Remote `app-server`. It must **not** assign `Sol`, `Terra`, or any other model to an account. Codex should discover the models allowed for the newly active account, and the user chooses the model from the Codex Desktop UI.

### What this project covers

- Multiple VPS hosts used through Codex Desktop SSH Remote connections.
- Multiple ChatGPT profiles with independent credentials on every VPS.
- Optional API-key profiles.
- Central account switching from Windows through a master VPS.
- Safe handling of `~/.codex/auth.json` and per-profile snapshots.
- Clearing stale `model` / `model_reasoning_effort` settings only when the account actually changes.
- Restarting the Remote Codex `app-server` after an account change.
- Separating real backend errors from misleading UI messages such as `You've hit your usage limit`.
- Read-only diagnosis, backups, verification, and rollback.
- Installable Linux and Windows helpers for reproducing the setup on a new system.

### Repository layout

```text
codex-remote-vps-multi-account/
├── SKILL.md
├── scripts/
│   ├── codex-auth
│   ├── codex-auth-local
│   ├── install-master.sh
│   └── install-node.sh
├── windows/
│   ├── codex-auth.ps1
│   └── install-windows.ps1
└── references/
    ├── install.md
    └── runbook.md
```

- `SKILL.md` contains the reusable agent workflow.
- `references/runbook.md` contains the detailed operational and troubleshooting procedures.
- `references/install.md` contains the clean-system deployment guide.
- `scripts/` contains the Linux auth manager and installers.
- `windows/` contains the Windows client helper and installer.

### Quick start

The detailed procedure is in `codex-remote-vps-multi-account/references/install.md`.

On every VPS, after Codex is installed and independently logged into the initial account:

```bash
cd Codex-Remote-VPS-multi-account/codex-remote-vps-multi-account
bash scripts/install-node.sh --initial-profile chatgpt-current
```

On the chosen master VPS:

```bash
bash scripts/install-master.sh --remote vps-two
```

On Windows:

```powershell
cd .\Codex-Remote-VPS-multi-account\codex-remote-vps-multi-account\windows
.\install-windows.ps1 -MasterAlias webmaster
```

Then normal operation is intentionally short:

```powershell
codex-auth status
codex-auth list
codex-auth add-chatgpt chatgpt-account2
codex-auth use chatgpt-account2
```

After a real account switch, reconnect the Remote project if needed and choose any model shown for that account in the Codex Desktop UI.

### Installation as a skill

Install or copy the `codex-remote-vps-multi-account` directory as a Codex/ChatGPT skill, or point your skill installer at this GitHub repository.

OpenAI describes a skill as a directory centered on a `SKILL.md` file, optionally with supporting resources. See:

- https://openai.com/academy/skills/
- https://help.openai.com/en/articles/20001066

### Safety

Never commit or paste any of the following into this repository, an issue, a chat, or a log:

- `auth.json`
- API keys
- access tokens
- refresh tokens
- device-login secrets
- private SSH keys

Only masked identifiers, hashes, status output, and non-secret configuration should be shared during troubleshooting.

Each VPS should obtain and maintain its own ChatGPT login state. Do not copy one live ChatGPT `auth.json` to another concurrently active VPS.

### Validated operating model

The workflow was developed against a Windows Codex Desktop client using Ubuntu VPS hosts. The important behavior is generic: Codex Desktop starts a Codex `app-server` on the remote host over SSH, and the remote host's active Codex credentials and configuration determine the Remote session state.

A successful baseline looks like:

```text
codex login status
Logged in using ChatGPT

codex exec --ephemeral --skip-git-repo-check 'Reply with exactly: VPS_DIRECT_OK'
...
VPS_DIRECT_OK
```

After an account change, the expected lifecycle is:

```text
switch auth
    -> clear stale model selection
    -> restart remote app-server
    -> reconnect Codex Desktop Remote
    -> Codex discovers models allowed for the new account
    -> user selects a model in the UI
```

If the same profile is selected again, the helper preserves the user's current model choice and does not restart the app-server.

---

<a id="فارسی"></a>

## فارسی

این پروژه یک Skill و مجموعه ابزار نصب قابل‌استفاده مجدد برای مدیریت **اتصال‌های Remote در Codex Desktop از طریق SSH** روی چند VPS و با چند پروفایل احراز هویت ChatGPT/API است.

قانون اصلی پروژه ساده است:

> **تغییر حساب احراز هویت و انتخاب مدل دو موضوع جدا از هم هستند.**

مدیر احراز هویت می‌تواند حساب فعال را تغییر دهد، model pin باقی‌مانده از حساب قبلی را پاک کند و `app-server` مربوط به Remote را دوباره راه‌اندازی کند. اما **نباید** یک حساب را به `Sol`، `Terra` یا هر مدل مشخص دیگری متصل یا مجبور کند. Codex باید مدل‌های مجاز برای حساب فعال جدید را خودش تشخیص دهد و کاربر مدل موردنظر را از داخل رابط Codex Desktop انتخاب کند.

### این پروژه چه چیزهایی را پوشش می‌دهد

- استفاده از چند VPS از طریق اتصال SSH Remote در Codex Desktop.
- چند پروفایل ChatGPT با credential مستقل روی هر VPS.
- پشتیبانی اختیاری از پروفایل‌های API Key.
- تغییر مرکزی حساب‌ها از Windows از طریق یک Master VPS.
- مدیریت امن `~/.codex/auth.json` و snapshot جداگانه برای هر پروفایل.
- پاک‌کردن تنظیمات قدیمی `model` و `model_reasoning_effort` فقط زمانی که حساب واقعاً تغییر می‌کند.
- راه‌اندازی مجدد `app-server` مربوط به Codex Remote پس از تغییر حساب.
- تفکیک خطاهای واقعی backend از پیام‌های گمراه‌کننده UI مانند `You've hit your usage limit`.
- عیب‌یابی فقط‌خواندنی، Backup، Verification و Rollback.
- Helperها و Installerهای قابل‌نصب برای Linux و Windows جهت بازسازی همین ساختار روی سیستم جدید.

### ساختار Repository

```text
codex-remote-vps-multi-account/
├── SKILL.md
├── scripts/
│   ├── codex-auth
│   ├── codex-auth-local
│   ├── install-master.sh
│   └── install-node.sh
├── windows/
│   ├── codex-auth.ps1
│   └── install-windows.ps1
└── references/
    ├── install.md
    └── runbook.md
```

- `SKILL.md` شامل workflow قابل‌استفاده مجدد برای Agent است.
- `references/runbook.md` شامل مراحل عملیاتی و عیب‌یابی با جزئیات است.
- `references/install.md` راهنمای نصب روی یک سیستم تمیز است.
- پوشه `scripts/` شامل مدیر احراز هویت Linux و Installerهای آن است.
- پوشه `windows/` شامل Helper و Installer سمت Windows است.

### شروع سریع

راهنمای کامل نصب در فایل `codex-remote-vps-multi-account/references/install.md` قرار دارد.

روی هر VPS، پس از نصب Codex و Login مستقل به حساب اولیه:

```bash
cd Codex-Remote-VPS-multi-account/codex-remote-vps-multi-account
bash scripts/install-node.sh --initial-profile chatgpt-current
```

روی VPS انتخاب‌شده به‌عنوان Master:

```bash
bash scripts/install-master.sh --remote vps-two
```

روی Windows:

```powershell
cd .\Codex-Remote-VPS-multi-account\codex-remote-vps-multi-account\windows
.\install-windows.ps1 -MasterAlias webmaster
```

بعد از نصب، استفاده عادی عمداً ساده و کوتاه است:

```powershell
codex-auth status
codex-auth list
codex-auth add-chatgpt chatgpt-account2
codex-auth use chatgpt-account2
```

پس از تغییر واقعی حساب، اگر لازم بود Remote project را دوباره متصل کنید و یکی از مدل‌هایی را که برای آن حساب در Codex Desktop نمایش داده می‌شود انتخاب کنید.

### نصب به‌عنوان Skill

پوشه `codex-remote-vps-multi-account` را به‌عنوان یک Skill برای Codex/ChatGPT نصب یا کپی کنید، یا Installer مربوط به Skill را مستقیماً به همین Repository در GitHub متصل کنید.

OpenAI یک Skill را به‌صورت یک پوشه با فایل مرکزی `SKILL.md` تعریف می‌کند که می‌تواند منابع و فایل‌های کمکی دیگری هم داشته باشد. برای اطلاعات بیشتر:

- https://openai.com/academy/skills/
- https://help.openai.com/en/articles/20001066

### امنیت

هیچ‌وقت موارد زیر را داخل این Repository، Issue، Chat یا Log قرار ندهید:

- `auth.json`
- API Keyها
- Access Tokenها
- Refresh Tokenها
- Device Login secretها
- Private SSH Keyها

در زمان عیب‌یابی فقط شناسه‌های Mask شده، Hashها، خروجی وضعیت و تنظیمات غیرمحرمانه را به اشتراک بگذارید.

هر VPS باید Login مربوط به ChatGPT را به‌صورت مستقل دریافت و نگهداری کند. یک `auth.json` فعال ChatGPT را از یک VPS به VPS دیگری که هم‌زمان فعال است کپی نکنید.

### مدل عملیاتی تأییدشده

این workflow با Codex Desktop روی Windows و VPSهای Ubuntu توسعه و آزمایش شده است. رفتار اصلی عمومی است: Codex Desktop از طریق SSH یک `app-server` روی VPS راه‌اندازی می‌کند و credential و configuration فعال Codex روی همان VPS وضعیت Remote session را تعیین می‌کنند.

نمونه وضعیت سالم:

```text
codex login status
Logged in using ChatGPT

codex exec --ephemeral --skip-git-repo-check 'Reply with exactly: VPS_DIRECT_OK'
...
VPS_DIRECT_OK
```

بعد از تغییر حساب، چرخه مورد انتظار به این شکل است:

```text
switch auth
    -> clear stale model selection
    -> restart remote app-server
    -> reconnect Codex Desktop Remote
    -> Codex discovers models allowed for the new account
    -> user selects a model in the UI
```

یعنی:

```text
تغییر احراز هویت
    -> پاک‌کردن انتخاب مدل باقی‌مانده از حساب قبلی
    -> راه‌اندازی مجدد app-server روی VPS
    -> اتصال مجدد Codex Desktop Remote
    -> شناسایی مدل‌های مجاز حساب جدید توسط Codex
    -> انتخاب مدل توسط کاربر از داخل UI
```

اگر همان پروفایل فعال دوباره انتخاب شود، Helper انتخاب مدل فعلی کاربر را حفظ می‌کند و `app-server` را دوباره راه‌اندازی نمی‌کند.
