import { apiInitializer } from "discourse/lib/api";

// YouTube-style scrollable topic navigation: wraps #navigation-bar in a scroller and
// adds the two edge arrows. Merged in from the standalone "youtube style menu
// scrollable" component, which fought this theme over .navigation-container and
// registered the same navigation-bar-dropdown-mode transformer twice. Styles live in
// scss/nav-scroller.scss.
//
// The transformer stays in init.gjs (one registration, one place).

const EDGE = 2; // px of slack before an arrow counts as "at the end"

function setupNavigationButtons() {
  const nav = document.querySelector("#navigation-bar");
  if (!nav || nav.dataset.ctNavButtons === "true") {
    return;
  }

  let scroller = nav.parentElement;
  if (!scroller) {
    return;
  }

  nav.dataset.ctNavButtons = "true";

  if (!scroller.classList.contains("ct-nav-scroller")) {
    const wrapper = document.createElement("div");
    wrapper.className = "ct-nav-scroller";
    scroller.insertBefore(wrapper, nav);
    wrapper.append(nav);
    scroller = wrapper;
  }

  scroller.querySelectorAll(".ct-nav-arrow").forEach((el) => el.remove());

  const arrow = (dir) => {
    const side = dir < 0 ? "left" : "right";
    const button = document.createElement("button");
    button.type = "button";
    button.className = `ct-nav-arrow ct-nav-arrow-${side}`;
    button.setAttribute("aria-label", `Scroll navigation ${side}`);
    button.textContent = dir < 0 ? "‹" : "›";
    button.addEventListener("click", () =>
      nav.scrollBy({
        left: dir * Math.max(nav.clientWidth * 0.7, 250),
        behavior: "smooth",
      })
    );
    return button;
  };

  const leftButton = arrow(-1);
  const rightButton = arrow(1);
  scroller.append(leftButton, rightButton);

  const updateButtons = () => {
    const maxScroll = nav.scrollWidth - nav.clientWidth;
    const hasOverflow = maxScroll > EDGE;

    leftButton.classList.toggle(
      "is-hidden",
      !hasOverflow || nav.scrollLeft <= EDGE
    );
    rightButton.classList.toggle(
      "is-hidden",
      !hasOverflow || nav.scrollLeft >= maxScroll - EDGE
    );
  };

  nav.addEventListener("scroll", updateButtons, { passive: true });
  new ResizeObserver(updateButtons).observe(nav);
  new MutationObserver(updateButtons).observe(nav, { childList: true });
  requestAnimationFrame(updateButtons);
}

export default apiInitializer((api) => {
  api.onPageChange(() => requestAnimationFrame(setupNavigationButtons));
});
