# Tyler Everage — Portfolio

A simple, pastel, animated portfolio site for an aspiring game designer
focused on **level design** and **character design**.

Built as a static site — no build step, no dependencies. Just HTML, CSS, and
a little vanilla JavaScript. Hosted on GitHub Pages at
[dezziiii.github.io](https://dezziiii.github.io).

## Structure

```
index.html      Page markup & content
css/styles.css  Styles, pastel palette, animations
js/main.js      Cursor, reveals, magnetic buttons, tilt, parallax
```

## Make it yours

- **Projects** live in the `<ul class="projects">` block in `index.html`.
  Swap the placeholder titles, descriptions, and the `--swatch-a` / `--swatch-b`
  colors. To use real images, replace the `.project__media` gradient with an
  `<img>`.
- **About text & facts** are in the `#about` section.
- **Social links** (ArtStation, Itch.io, LinkedIn) are placeholders — drop in
  your real URLs in the `#contact` section.
- **Colors** are CSS variables at the top of `css/styles.css` (`:root`).

## Develop locally

Open `index.html` in a browser, or run any static server:

```bash
python3 -m http.server 8000
# then visit http://localhost:8000
```
