Put your project images here (e.g. sunken-cathedral.jpg, the-tinkerer.png).

Then, in index.html, replace a card's gradient placeholder:

    <div class="card__media card__media--a" data-cursor="View">
      <span class="card__index">01</span>
    </div>

with a real image:

    <div class="card__media" data-cursor="View">
      <img src="assets/your-image.jpg" alt="Short description of the work" />
    </div>

Tips:
- Landscape images around 1280x800 look best (cards are 16:10).
- Keep file sizes reasonable (under ~400 KB) so the page stays fast.
- Always write a short, descriptive alt for accessibility.
