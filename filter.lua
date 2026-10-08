-- filter.lua — see notes/specs/2026-05-26-editorial-cv-template-design.md
local short_version = false
local industry_version = false
-- True when rendering to HTML (the web build). Every LaTeX-specific
-- construct below has an HTML counterpart built from pandoc AST nodes, so
-- the HTML writer handles escaping and heading ids (incl. --id-prefix).
local html_output = false
local section = nil   -- normalized name of the current H1 section
local pandoc_utils = pandoc.utils

local function normalize(s)
  return s:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Split a "**Org, Years**" paragraph into org + years.
-- Returns nil if the paragraph isn't a single Strong containing the pattern.
local function split_org_years(block)
  if block.t ~= "Para" then return nil end
  if #block.content ~= 1 or block.content[1].t ~= "Strong" then return nil end
  local text = pandoc_utils.stringify(block.content[1])
  -- Match trailing ", YYYY[--YYYY|--Present|--<word>]"
  local org, years = text:match("^(.-),%s*(%d%d%d%d[%-–][%-–%w]*)$")
  if not org then
    org, years = text:match("^(.-),%s*(%d%d%d%d)$")
  end
  if not org then return nil end
  -- Normalize en-dash variants to LaTeX "--"
  years = years:gsub("[–%-]+", "--")
  return org, years
end

local function is_cv_section()
  return section == "experience" or section == "education"
end

-- ─── [LONG] handling ────────────────────────────────────────────────────────
-- We support three source forms for hiding content in the short version:
--
--   1. Standalone tag paragraphs (block-level wrap):
--        [LONG]
--
--        # Some section
--        content...
--
--        [/LONG]
--
--   2. Orphan-leading / orphan-trailing tag in a paragraph that's part of a
--      larger block (the tag is followed/preceded by a SoftBreak):
--        [LONG]
--        Dissertation: *Some title*
--
--        Advisors: A, B
--        [/LONG]
--
--   3. Both tags inline within a single paragraph (skills/pills idiom):
--        [LONG]
--        - Item 1
--        - Item 2
--        [/LONG]
--
-- The pipeline is two passes: normalize_tag_paras splits form (2) into
-- standalone tag paragraphs, then resolve_block_tag collapses standalone
-- tag pairs. Form (3) — both tags in one paragraph — is left intact for
-- the main loop's section-specific handlers (skills/programming-languages
-- render the dashed list as pills).

-- Pre-pass 1: split paragraphs whose leading inline is `[TAG]` (followed by
-- a soft/line break) or whose trailing inline is `[/TAG]` (preceded by one).
-- Paragraphs containing both tags or neither are passed through unchanged.
local function normalize_tag_paras(blocks, tag)
  local open_lit  = "[" .. tag .. "]"
  local close_lit = "[/" .. tag .. "]"
  local open_pat  = "%[" .. tag .. "%]"
  local close_pat = "%[/" .. tag .. "%]"
  local out = {}
  for _, b in ipairs(blocks) do
    local emitted = false
    if b.t == "Para" and #b.content > 0 then
      local inlines = b.content
      local n = #inlines
      local text = pandoc_utils.stringify(b)
      local has_open = text:find(open_pat) ~= nil
      local has_close = text:find(close_pat) ~= nil
      if has_open ~= has_close then
        local is_break = function(x)
          return x.t == "SoftBreak" or x.t == "LineBreak"
        end
        if has_open
            and n >= 2
            and inlines[1].t == "Str" and inlines[1].text == open_lit
            and is_break(inlines[2]) then
          table.insert(out, pandoc.Para({pandoc.Str(open_lit)}))
          local rest = {}
          for i = 3, n do table.insert(rest, inlines[i]) end
          if #rest > 0 then table.insert(out, pandoc.Para(rest)) end
          emitted = true
        elseif has_close
            and n >= 2
            and inlines[n].t == "Str" and inlines[n].text == close_lit
            and is_break(inlines[n-1]) then
          local rest = {}
          for i = 1, n - 2 do table.insert(rest, inlines[i]) end
          if #rest > 0 then table.insert(out, pandoc.Para(rest)) end
          table.insert(out, pandoc.Para({pandoc.Str(close_lit)}))
          emitted = true
        end
      end
    end
    if not emitted then table.insert(out, b) end
  end
  return out
end

-- Pre-pass 1b: trim bullet lists with inline [LONG]/[/LONG] markers. Pandoc
-- parses
--
--   - visible
--   - last visible
--   [LONG]
--   - hidden
--   - last hidden
--   [/LONG]
--   - after
--
-- as a single BulletList where the orphan `[LONG]` line attaches as the
-- trailing inline of the preceding item (after a SoftBreak), and likewise
-- for `[/LONG]`. This pass detects that pattern, strips the tag from the
-- item, and in short mode drops the items between the open and close tags.
local function process_bullet_items_long(items)
  local out = {}
  local in_long = false
  for _, item in ipairs(items) do
    local last = item[#item]
    local trailing = nil  -- "open" | "close" | nil
    local stripped = item
    if last and (last.t == "Plain" or last.t == "Para") then
      local inl = last.content
      local m = #inl
      if m >= 2
          and inl[m].t == "Str"
          and (inl[m].text == "[LONG]" or inl[m].text == "[/LONG]")
          and (inl[m-1].t == "SoftBreak" or inl[m-1].t == "LineBreak") then
        trailing = (inl[m].text == "[LONG]") and "open" or "close"
        local new_inl = {}
        for k = 1, m - 2 do table.insert(new_inl, inl[k]) end
        local new_last = (last.t == "Plain")
          and pandoc.Plain(new_inl) or pandoc.Para(new_inl)
        stripped = {}
        for k = 1, #item - 1 do table.insert(stripped, item[k]) end
        table.insert(stripped, new_last)
      end
    end
    if not (in_long and short_version) then
      table.insert(out, stripped)
    end
    if trailing == "open" then in_long = true
    elseif trailing == "close" then in_long = false end
  end
  return out
end

local function trim_lists_with_inline_long(blocks)
  local doc = pandoc.Pandoc(blocks)
  local result = doc:walk({
    BulletList = function(b)
      return pandoc.BulletList(process_bullet_items_long(b.content))
    end
  })
  return result.blocks
end

-- Pre-pass 2: resolve standalone [TAG] / [/TAG] tag paragraphs.
-- Drops the wrapped blocks when `hide` is true; drops only the tag paragraphs
-- otherwise. Supports nesting via depth counting. Emits a stderr warning on
-- any unmatched tag (the integration test fails on these).
local function resolve_block_tag(blocks, tag, hide)
  local open_pat  = "%[" .. tag .. "%]"
  local close_pat = "%[/" .. tag .. "%]"
  local function is_tag(b, pat)
    if b.t ~= "Para" then return false end
    return pandoc_utils.stringify(b):match("^%s*" .. pat .. "%s*$") ~= nil
  end
  local out = {}
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    if is_tag(b, open_pat) then
      local depth = 1
      local j = i + 1
      while j <= #blocks do
        if is_tag(blocks[j], open_pat) then depth = depth + 1
        elseif is_tag(blocks[j], close_pat) then
          depth = depth - 1
          if depth == 0 then break end
        end
        j = j + 1
      end
      if j > #blocks then
        io.stderr:write("filter.lua: warning: unmatched [" .. tag .. "] tag\n")
      end
      if not hide then
        for k = i + 1, math.min(j - 1, #blocks) do
          table.insert(out, blocks[k])
        end
      end
      i = j + 1
    elseif is_tag(b, close_pat) then
      io.stderr:write("filter.lua: warning: orphan [/" .. tag .. "] tag (dropped)\n")
      i = i + 1
    else
      table.insert(out, b)
      i = i + 1
    end
  end
  return out
end

-- Render a slice of blocks (the "detail" of a CV entry) to LaTeX. The slice
-- has already been through normalize+resolve, so it contains no standalone
-- tag paragraphs. Inline [LONG]...[/LONG] paragraphs (both tags in one Para)
-- are stripped here: tags removed in full mode, whole bracketed span
-- removed in short mode.
local function render_detail(blocks)
  local cleaned = {}
  for _, b in ipairs(blocks) do
    if b.t == "Para" then
      local s = pandoc_utils.stringify(b)
      if s:find("%[LONG%]") and s:find("%[/LONG%]") then
        if short_version then
          local stripped = s:gsub("%[LONG%].-%[/LONG%]", "")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        else
          local stripped = s:gsub("%[LONG%]",""):gsub("%[/LONG%]","")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        end
      else
        table.insert(cleaned, b)
      end
    else
      table.insert(cleaned, b)
    end
  end
  if html_output then return cleaned end
  if #cleaned == 0 then return "" end
  return pandoc.write(pandoc.Pandoc(cleaned), "latex")
end

-- HTML helpers -------------------------------------------------------------

local function div(blocks, class)
  return pandoc.Div(blocks, pandoc.Attr("", {class}))
end

-- A list of strings rendered as a <ul> of pills.
local function html_pills(items)
  local list = {}
  for _, t in ipairs(items) do
    table.insert(list, {pandoc.Plain({pandoc.Str(t)})})
  end
  return div({pandoc.BulletList(list)}, "pills")
end

function Pandoc(doc)
  html_output = FORMAT:match("html") ~= nil
  if doc.meta and doc.meta.short_version then
    short_version = pandoc_utils.stringify(doc.meta.short_version) == "true"
  end
  if doc.meta and doc.meta.industry_version then
    industry_version = pandoc_utils.stringify(doc.meta.industry_version) == "true"
  end
  if industry_version and doc.meta and doc.meta["tagline-industry"] then
    doc.meta.tagline = doc.meta["tagline-industry"]
  end
  -- The full (academic) version uses the institutional email address.
  if not short_version and not industry_version
      and doc.meta and doc.meta["email-academic"] then
    doc.meta.email = doc.meta["email-academic"]
  end

  local blocks = normalize_tag_paras(doc.blocks, "LONG")
  blocks = normalize_tag_paras(blocks, "ACADEMIC")
  blocks = normalize_tag_paras(blocks, "INDUSTRY")
  blocks = resolve_block_tag(blocks, "LONG", short_version)
  blocks = resolve_block_tag(blocks, "ACADEMIC", industry_version)
  blocks = resolve_block_tag(blocks, "INDUSTRY", not industry_version)
  blocks = trim_lists_with_inline_long(blocks)
  local out = {}
  local i = 1
  while i <= #blocks do
    local b = blocks[i]

    -- Track current H1 section.
    if b.t == "Header" and b.level == 1 then
      section = normalize(pandoc_utils.stringify(b))
      -- If this section opens with a [CALLOUT] containing a single short
      -- paragraph, render the section title and callout content side-by-side
      -- via \sectionwithcallout (the section spans the full width; the
      -- callout content sits flush-right on the title baseline).
      local nb = blocks[i + 1]
      if nb and nb.t == "Para"
          and pandoc_utils.stringify(nb):match("^%s*%[CALLOUT%]%s*$") then
        local j = i + 2
        local content_blocks = {}
        while j <= #blocks do
          local bj = blocks[j]
          if bj.t == "Para"
              and pandoc_utils.stringify(bj):match("^%s*%[/CALLOUT%]%s*$") then
            j = j + 1
            break
          end
          table.insert(content_blocks, bj)
          j = j + 1
        end
        if html_output and #content_blocks == 1
            and content_blocks[1].t == "Para" then
          -- HTML: keep the real header; the stats line follows it.
          table.insert(out, b)
          table.insert(out, div({pandoc.Para(content_blocks[1].content)},
                                "section-stats"))
          i = j
        elseif #content_blocks == 1 and content_blocks[1].t == "Para" then
          -- Render the single paragraph inline (no \par at end).
          local plain = pandoc.Plain(content_blocks[1].content)
          local content_tex = pandoc.write(pandoc.Pandoc({plain}), "latex")
                              :gsub("^%s+", ""):gsub("%s+$", "")
          local title = pandoc_utils.stringify(b)
          table.insert(out, pandoc.RawBlock("latex",
            string.format("\\sectionwithcallout{%s}{%s}", title, content_tex)))
          i = j
        else
          -- Multi-block callout: fall through to default behaviour
          -- (emit the header, then the callout markers will be handled below).
          table.insert(out, b)
          i = i + 1
        end
      else
        table.insert(out, b)
        i = i + 1
      end

    -- In CV sections, fold "## Title" + "**Org, Years**" + detail into \cvitem.
    elseif b.t == "Header" and b.level == 2 and is_cv_section() then
      local title = pandoc_utils.stringify(b)
      local next_b = blocks[i + 1]
      local org, years = nil, nil
      if next_b then org, years = split_org_years(next_b) end
      if org then
        -- Collect detail blocks up to the next H2 or H1.
        local detail = {}
        local j = i + 2
        while j <= #blocks do
          local bj = blocks[j]
          if bj.t == "Header" and (bj.level == 1 or bj.level == 2) then break end
          table.insert(detail, bj)
          j = j + 1
        end
        if html_output then
          local head = {
            pandoc.Header(2, b.content, b.attr),
            div({pandoc.Plain({pandoc.Str(org)})}, "cv-org"),
            div({pandoc.Plain({pandoc.Str((years:gsub("%-%-", "–")))})},
                "cv-years"),
          }
          local item = {div(head, "cv-head")}
          local detail_blocks = render_detail(detail)
          if #detail_blocks > 0 then
            table.insert(item, div(detail_blocks, "cv-detail"))
          end
          table.insert(out, div(item, "cv-item"))
          i = j
          goto continue
        end
        local detail_tex = render_detail(detail):gsub("%s+$", "")
        local tex = string.format("\\cvitem{%s}{%s}{%s}{%s}",
          title, org, years, detail_tex)
        table.insert(out, pandoc.RawBlock("latex", tex))
        i = j
      else
        table.insert(out, b)
        i = i + 1
      end

    -- [CALLOUT] markers — wrap the following blocks in a callout environment.
    elseif b.t == "Para" and pandoc_utils.stringify(b):match("^%s*%[CALLOUT%]%s*$") then
      table.insert(out, html_output
        and pandoc.RawBlock("html", '<div class="callout">')
        or pandoc.RawBlock("latex", "\\begin{callout}"))
      i = i + 1
    elseif b.t == "Para" and pandoc_utils.stringify(b):match("^%s*%[/CALLOUT%]%s*$") then
      table.insert(out, html_output
        and pandoc.RawBlock("html", "</div>")
        or pandoc.RawBlock("latex", "\\end{callout}"))
      i = i + 1

    -- Skills section: render bullet list as inline \pill{} tags.
    elseif b.t == "BulletList" and (section == "skills" or section == "programming languages") then
      local parts, texts = {}, {}
      for _, item in ipairs(b.content) do
        local item_text = pandoc_utils.stringify(item):gsub("%s+", " ")
                                                      :gsub("^%s+", "")
                                                      :gsub("%s+$", "")
        if item_text ~= "" then
          table.insert(texts, item_text)
          table.insert(parts, "\\pill{" .. item_text .. "}")
        end
      end
      if html_output then
        table.insert(out, html_pills(texts))
        i = i + 1
        goto continue
      end
      local line = "\\pillrow{" .. table.concat(parts, "\\,\\allowbreak\\,") .. "}"
      table.insert(out, pandoc.RawBlock("latex", line))
      i = i + 1

    -- Languages section: render bullet list as inline " · "-joined string.
    elseif b.t == "BulletList" and section == "languages" then
      if html_output then
        local list = {}
        for _, item in ipairs(b.content) do
          local t = pandoc_utils.stringify(item):gsub("%s+", " ")
                                               :gsub("^%s+", ""):gsub("%s+$", "")
          local name, qual = t:match("^(.-)%s*%(([^)]+)%)$")
          local inl = name
            and {pandoc.Str(name), pandoc.Space(),
                 pandoc.Span({pandoc.Str("(" .. qual .. ")")},
                             pandoc.Attr("", {"qual"}))}
            or {pandoc.Str(t)}
          table.insert(list, {pandoc.Plain(inl)})
        end
        table.insert(out, div({pandoc.BulletList(list)}, "inline-list"))
        i = i + 1
        goto continue
      end
      local parts = {}
      for _, item in ipairs(b.content) do
        local item_text = pandoc_utils.stringify(item):gsub("%s+", " ")
                                                      :gsub("^%s+", "")
                                                      :gsub("%s+$", "")
        -- Grey out parenthetical level qualifier "(native)" etc.
        item_text = item_text:gsub("%s*%(([^)]+)%)$",
          " {\\color{secondary}\\small (%1)}")
        if item_text ~= "" then table.insert(parts, item_text) end
      end
      local line = table.concat(parts, " \\,\\ensuremath{\\cdot}\\, ")
      table.insert(out, pandoc.RawBlock("latex", line))
      i = i + 1

    -- Inline [LONG]...[/LONG] within a single paragraph. After the
    -- normalize+resolve pre-passes, only this form remains.
    elseif b.t == "Para" then
      local text = pandoc_utils.stringify(b)
      if text:find("%[LONG%]") and text:find("%[/LONG%]") then
        if short_version then
          local s = text:gsub("%[LONG%].-%[/LONG%]", "")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        elseif section == "skills" or section == "programming languages" then
          local inner = text:gsub("%[LONG%]",""):gsub("%[/LONG%]","")
          local parts, texts = {}, {}
          for item in inner:gmatch("[^%-\n]+") do
            item = item:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if item ~= "" then
              table.insert(texts, item)
              table.insert(parts, "\\pill{" .. item .. "}")
            end
          end
          if html_output then
            if #texts > 0 then table.insert(out, html_pills(texts)) end
          elseif #parts > 0 then
            table.insert(out, pandoc.RawBlock("latex",
              "\\pillrow{" .. table.concat(parts, "\\,\\allowbreak\\,") .. "}"))
          end
        else
          local s = text:gsub("%[LONG%]",""):gsub("%[/LONG%]","")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        end
      else
        table.insert(out, b)
      end
      i = i + 1

    else
      table.insert(out, b)
      i = i + 1
    end
    ::continue::
  end

  -- Second pass: in Publications, rewrap "(cited by N)" as \cites{N}.
  -- Works directly on inlines to preserve existing emphasis/formatting.
  local cur_section = nil
  local function rewrap_cites(el)
    if cur_section ~= "publications" then return nil end
    local text = pandoc_utils.stringify(el)
    local n = text:match("%(cited by (%d+)%)%s*$")
    if not n then return nil end
    -- Rebuild the inline list: copy all inlines, trim the trailing
    -- " (cited by N)" tokens, then append \cites{N}.
    local src = {}
    for _, inline in ipairs(el.content) do
      table.insert(src, inline)
    end
    -- Walk backwards to strip: the tail looks like
    --   ... Str("(cited") Space Str("by") Space Str("N)") [Space]
    -- Trim trailing Spaces first.
    while #src > 0 and src[#src].t == "Space" do
      table.remove(src)
    end
    -- Now the last token should be Str ending with ")".
    -- Strip " (cited by N)" by removing the last 5 tokens:
    -- Str("(cited") Space Str("by") Space Str("N)")
    -- but the Str tokens may vary; use stringify on the remainder to verify.
    -- Safer: remove from the end until the closing ")" Str is gone.
    -- Remove tokens from the end until "(cited" is gone from stringified text.
    local found = false
    for _ = 1, 10 do  -- bounded loop
      if #src == 0 then break end
      table.remove(src)
      local rejoined = pandoc_utils.stringify(pandoc.Para(pandoc.Inlines(src)))
      if not rejoined:match("%(cited") then
        found = true
        break
      end
    end
    if not found then
      -- Could not strip; return unchanged.
      return nil
    end
    -- Trim trailing space/punct that was before "(cited by N)".
    while #src > 0 and src[#src].t == "Space" do
      table.remove(src)
    end
    table.insert(src, pandoc.Space())
    if html_output then
      table.insert(src, pandoc.RawInline("html",
        '<span class="cites"><span class="visually-hidden">cited by </span>'
        .. n .. '</span>'))
    else
      table.insert(src, pandoc.RawInline("latex", "\\cites{"..n.."}"))
    end
    local inlines = pandoc.Inlines(src)
    if el.t == "Para" then return pandoc.Para(inlines) end
    return pandoc.Plain(inlines)
  end

  local result = pandoc.Pandoc(out):walk{
    Header = function(h)
      if h.level == 1 then cur_section = normalize(pandoc_utils.stringify(h)) end
      return nil
    end,
    -- An H1 followed by a short [CALLOUT] was folded into a
    -- \sectionwithcallout RawBlock by the main loop; track it as a section too.
    RawBlock = function(rb)
      local title = rb.text:match("^\\sectionwithcallout{(.-)}{")
      if title then cur_section = normalize(title) end
      return nil
    end,
    Para  = rewrap_cites,
    Plain = rewrap_cites,
  }
  if html_output then
    -- The page title (the person's name) is the <h1>; demote sections to
    -- <h2> and entries to <h3>.
    result = result:walk{
      Header = function(h) h.level = h.level + 1; return h end,
    }
  end
  doc.blocks = result.blocks
  return doc
end
