// Progressive enhancement for the CV versions nav: without JavaScript the
// nav is a list of in-page links and every version is shown in turn. With
// it, the nav becomes a WAI-ARIA tablist (automatic activation, arrow-key /
// Home / End navigation) and the URL hash (#academic, #industry, ...) picks
// the visible version, so versions can be linked to directly.
(function () {
  "use strict";
  var list = document.querySelector("[data-tabs]");
  if (!list) return;
  var tabs = Array.prototype.slice.call(list.querySelectorAll('a[href^="#"]'));
  var panels = tabs.map(function (t) {
    return document.getElementById(t.getAttribute("href").slice(1));
  });
  if (panels.some(function (p) { return !p; })) return;

  list.setAttribute("role", "tablist");
  list.setAttribute("aria-label", "CV versions");
  tabs.forEach(function (tab, i) {
    tab.parentNode.setAttribute("role", "presentation");
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-controls", panels[i].id);
    panels[i].setAttribute("role", "tabpanel");
  });
  document.documentElement.classList.add("has-tabs");

  var baseTitle = document.title;

  function select(index, opts) {
    opts = opts || {};
    tabs.forEach(function (tab, i) {
      var on = i === index;
      tab.setAttribute("aria-selected", on ? "true" : "false");
      tab.tabIndex = on ? 0 : -1;
      panels[i].hidden = !on;
    });
    document.title = tabs[index].textContent + " · " + baseTitle;
    if (opts.focus) tabs[index].focus();
    if (opts.updateHash) {
      var hash = "#" + panels[index].id;
      if (location.hash !== hash) history.replaceState(null, "", hash);
    }
  }

  // Index of the panel that is, or contains, the element named by the hash.
  function indexForHash() {
    var id = decodeURIComponent(location.hash.slice(1));
    var target = id && document.getElementById(id);
    if (!target) return { index: 0, target: null };
    for (var i = 0; i < panels.length; i++) {
      if (panels[i] === target) return { index: i, target: null };
      if (panels[i].contains(target)) return { index: i, target: target };
    }
    return { index: 0, target: null };
  }

  function syncToHash() {
    var r = indexForHash();
    select(r.index);
    // A link to a whole version starts at the top of the page (with the
    // tabs in view); a link into a version scrolls to that heading.
    if (r.target) r.target.scrollIntoView();
    else window.scrollTo(0, 0);
  }

  tabs.forEach(function (tab, i) {
    tab.addEventListener("click", function (e) {
      e.preventDefault();
      select(i, { updateHash: true });
    });
    tab.addEventListener("keydown", function (e) {
      var next = null;
      switch (e.key) {
        case "ArrowRight": next = (i + 1) % tabs.length; break;
        case "ArrowLeft": next = (i - 1 + tabs.length) % tabs.length; break;
        case "Home": next = 0; break;
        case "End": next = tabs.length - 1; break;
        default: return;
      }
      e.preventDefault();
      select(next, { focus: true, updateHash: true });
    });
  });

  window.addEventListener("hashchange", syncToHash);
  syncToHash();
  // The browser's own jump to the #fragment can land after the call above;
  // redo the scroll once the page has finished loading.
  window.addEventListener("load", function () {
    if (!indexForHash().target) window.scrollTo(0, 0);
  });
})();
