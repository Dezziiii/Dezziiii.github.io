# Ronnie Tyler Everage — Game Design Portfolio

An animated, **multi-page** portfolio for level design work (character design coming
next), built with **plain HTML, CSS, and JavaScript** — no frameworks, no build step,
no dependencies. (You do **not** need Wix — host these files directly and you keep the
exact look and every animation. See "Publish it" below.)

The **home page structure is modeled based on [ref.digital](https://ref.digital)** (statement
hero, selected-work cards, a 4-card "What I do" row, structured footer). The **Writing
and Contact pages** take cues from [carterogunsola.com](https://carterogunsola.com) — a
monospace status ticker, a writing page, and a letter-style contact with a
signature pad. Everything is dressed in a warm **coffee** palette (deep espresso,
mocha, umber, cocoa) with **soft-lavender purple accents** kept to ~10% of the UI.
There's a **light "latte" / dark "espresso" theme toggle** — the site **defaults to dark**.

Goes by **Tyler**. Based in **Fountain, CO**.

---

## Preview it locally

**Easiest:** double-click `index.html`.

**Nicer (any tiny static server):** for example, with Python installed:

```bash
python -m http.server 4321
```

then open <http://localhost:4321>. (VS Code's "Live Server" extension works too.)

---

## Project structure

```
Portfolio/
├─ index.html        ← Home (hero, selected work, "what I do", level design, about, contact)
├─ writing.html      ← Devlog/notes list with category filters
├─ contact.html      ← Letter-style contact + receipt stub + signature pad
├─ css/styles.css    ← all styling. Colors/themes + fonts live at the top in :root
├─ js/main.js        ← animations & interactions (shared by every page)
├─ assets/           ← project videos (.mp4), poster frames & stills (.jpg)
└─ README.md
```

The nav, status ticker, and footer are repeated in each `.html` file (no build step),
so if you change one, update the others to match.

**Themes:** the toggle in the nav flips between a light "latte" and dark "espresso"
theme; the choice is saved and **defaults to dark** (change `if (!t) t = "dark";` in the
`<head>` script of each page to default to light or the visitor's system setting). All
colors (both themes) live in the `:root` and `[data-theme="dark"]` blocks at the top of
`css/styles.css`.

**Status ticker:** the monospace strip up top is in each page's HTML — it currently reads
`FOUNTAIN, CO`, `OPEN · 2026 ROLES`, `FOCUS LEVEL DESIGN`, `BOOKING 2026`. The clock is live.

**Letter contact:** `contact.html` builds a `mailto:` from the chosen subject, name, and
note when "Send it" is clicked — the address is set in `data-email` / `data-copy`
(`everage.ronnie.t@gmail.com`). The signature pad is a nice touch; it isn't submitted anywhere.

---

## The work (two level projects)

Both projects live on the home page: the two **Selected work** cards up top, then the full
**Level Design** gallery grouped by project.

- **Outbreak** — survival-horror level (military outpost → underground lab). UE5.
- **Crash Site** — horror blockout (downed plane + dead-end alley, lit for guidance). UE5.

**Character Design** shows a "Work coming soon" placeholder until you have pieces to add.

### How the media was made (important)

Your original gameplay GIFs were **66 MB–522 MB each (~1.7 GB total)** — far too heavy for
the web. They were converted to small looping **MP4s** (a few MB each) with **ffmpeg**, with
a **poster JPG** pulled from each clip. The PNG stills were resized to web JPGs too. Everything
lives in `assets/`.

To add or replace a clip later, convert the GIF the same way (ffmpeg is installed via winget):

```powershell
ffmpeg -y -i input.gif -movflags +faststart -an -pix_fmt yuv420p `
  -vf "scale='min(1280,iw)':-2:flags=lanczos" -c:v libx264 -crf 27 -preset medium assets/my-clip.mp4
ffmpeg -y -ss 1 -i assets/my-clip.mp4 -frames:v 1 -q:v 4 assets/my-clip.jpg   # poster
```

Then drop it into a card — **videos play on hover**, images zoom on hover:

```html
<!-- Video card (plays on hover; poster shows until then) -->
<div class="card__media">
  <video src="assets/my-clip.mp4" poster="assets/my-clip.jpg" muted loop playsinline preload="metadata"></video>
</div>

<!-- Image card -->
<div class="card__media">
  <img src="assets/my-shot.jpg" alt="what it shows" loading="lazy" />
</div>
```

---

## How to make it yours

Search `index.html` for **`EDIT ME`** comments for the title/description.

### 1. Name, bio, email, links
The name shows as **Ronnie Tyler Everage** (with "goes by Tyler" noted on the hero + contact).
Email is `everage.ronnie.t@gmail.com`; socials are LinkedIn (`/in/ronnieeverage`) and Instagram
(`tylereverage2022`). They appear in the nav/footer of each page and the contact card — update
all three HTML files to keep them in sync.

### 2. Recolor / re-type the whole site (one place)
In `css/styles.css`, edit the tokens under `:root`:

```css
/* backgrounds — coffee */
--bg / --bg-2 / --surface          /* espresso → mocha → cocoa */
/* typography */
--ink / --ink-soft / --ink-dim     /* off-white / warm taupe / dusty (disabled) */
/* purple accents (interactive, ~10%) */
--accent      /* links + accent text   */
--btn / --btn-hover / --btn-ink    /* primary button: soft lavender / pale lilac / text */
--badge / --badge-text             /* tags & badges: deep plum / pale lilac */
/* warm caramel — drives the small mono labels (stays brown, not purple) */
--lav / --lav-deep / --lav-text
--font     /* swap the typeface here */
```

The dark "espresso" theme (the default) overrides the same tokens in the
`[data-theme="dark"]` block right below `:root`. To shift the accent to a different
hue, change `--accent`, `--btn`, and `--badge` in both blocks. Note: the caramel token
names (`--lav`, `--blush`) are leftovers from the original palette — they now hold the
warm browns used by the mono labels.

### 3. Add character work (when it's ready)
The Character Design section on `index.html` is a `.coming-soon` placeholder. When you have
pieces, swap it for a `.grid` of `.card`s just like the Level Design gallery.

---

## Publish it (free) — no Wix required

This is a normal static website, so any static host works and keeps the exact design
+ animations. **Wix can't import a code site** (its AI builder only generates an
approximation from a text description, and the custom motion/theme/letter wouldn't
carry over), so the simplest path is to host these files directly:

- **Netlify Drop** — drag this folder onto <https://app.netlify.com/drop>. Live in seconds.
- **GitHub Pages** — push to a repo → Settings → Pages → deploy from `main` (root).
- **Cloudflare Pages / Vercel** — also work. No build command needed.

The whole `assets/` folder is only ~12 MB, so any of these will load fast.

---

## Motion & "flashy" bits

Modeled on ref.digital's award-winning motion (it's built with GSAP + WebGL), done
here dependency-free:

- **Intro loader** — a counter + curtain reveal on first load.
- **Smooth inertial scrolling** — the page glides instead of jumping (desktop only).
- **Clip-wipe image reveals** + **word-by-word title animations** on scroll.
- **Mouse-parallax background** blobs + subtle scroll drift.
- **Text-scramble** hover on nav links, **count-up** on the bracketed numbers.
- **Custom cursor** + **magnetic** buttons.
- **Video-on-hover** on the project cards.

Tuning (all in `js/main.js`):
- **Loader:** delete the `<div class="loader">` from `index.html` to skip it entirely.
- **Smooth scroll feel:** change the `0.09` in `enableSmooth()` (higher = snappier).
- **Everything** auto-disables when a visitor has "reduce motion" enabled in their OS.

## Good to know

- **Accessibility:** text meets WCAG AA contrast; if a visitor has "reduce motion"
  enabled, all animations and the custom cursor turn off automatically.
- **Themes:** light "latte" + dark "espresso", toggled in the nav and remembered.
- **Fonts:** Space Grotesk loads from Google Fonts; falls back to system fonts offline.
