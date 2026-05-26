-- filter.lua — see docs/superpowers/specs/2026-05-26-editorial-cv-template-design.md
local short_version = false
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

-- Apply [LONG] stripping to a slice of blocks (the "detail" of a CV entry).
local function clean_long(blocks)
  local cleaned = {}
  local in_long = false
  for _, b in ipairs(blocks) do
    if b.t == "Para" then
      local s = pandoc_utils.stringify(b)
      if s:find("%[LONG%]") and s:find("%[/LONG%]") then
        if short_version then
          local stripped = s:gsub("%[LONG%].*%[/LONG%]", "")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        else
          local stripped = s:gsub("%[LONG%]",""):gsub("%[/LONG%]","")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        end
      elseif s:find("%[LONG%]") then
        in_long = true
        if not short_version then
          local stripped = s:gsub("%[LONG%]","")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        end
      elseif s:find("%[/LONG%]") then
        in_long = false
      elseif in_long then
        if not short_version then table.insert(cleaned, b) end
      else
        table.insert(cleaned, b)
      end
    else
      if not in_long or not short_version then
        table.insert(cleaned, b)
      end
    end
  end
  return cleaned
end

local function render_detail(blocks)
  local cleaned = clean_long(blocks)
  if #cleaned == 0 then return "" end
  return pandoc.write(pandoc.Pandoc(cleaned), "latex")
end

local function is_cv_section()
  return section == "experience" or section == "education"
end

function Pandoc(doc)
  if doc.meta and doc.meta.short_version then
    short_version = pandoc_utils.stringify(doc.meta.short_version) == "true"
  end

  local blocks = doc.blocks
  local out = {}
  local i = 1
  while i <= #blocks do
    local b = blocks[i]

    -- Track current H1 section.
    if b.t == "Header" and b.level == 1 then
      section = normalize(pandoc_utils.stringify(b))
      table.insert(out, b)
      i = i + 1

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
      table.insert(out, pandoc.RawBlock("latex", "\\begin{callout}"))
      i = i + 1
    elseif b.t == "Para" and pandoc_utils.stringify(b):match("^%s*%[/CALLOUT%]%s*$") then
      table.insert(out, pandoc.RawBlock("latex", "\\end{callout}"))
      i = i + 1

    -- [LONG] stripping for non-CV sections (legacy behaviour).
    elseif b.t == "Para" then
      local text = pandoc_utils.stringify(b)
      if text:find("%[LONG%]") and text:find("%[/LONG%]") then
        if short_version then
          local s = text:gsub("%[LONG%].*%[/LONG%]", "")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        else
          local s = text:gsub("%[LONG%]",""):gsub("%[/LONG%]","")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        end
        i = i + 1
      elseif text:find("%[LONG%]") then
        if not short_version then
          local s = text:gsub("%[LONG%]","")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        end
        -- Consume blocks until [/LONG]
        local j = i + 1
        while j <= #blocks do
          local bj = blocks[j]
          if bj.t == "Para" then
            local sj = pandoc_utils.stringify(bj)
            if sj:find("%[/LONG%]") then
              j = j + 1
              break
            end
          end
          if not short_version then table.insert(out, bj) end
          j = j + 1
        end
        i = j
      else
        table.insert(out, b)
        i = i + 1
      end

    else
      table.insert(out, b)
      i = i + 1
    end
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
    table.insert(src, pandoc.RawInline("latex", "\\cites{"..n.."}"))
    local inlines = pandoc.Inlines(src)
    if el.t == "Para" then return pandoc.Para(inlines) end
    return pandoc.Plain(inlines)
  end

  local result = pandoc.Pandoc(out):walk{
    Header = function(h)
      if h.level == 1 then cur_section = normalize(pandoc_utils.stringify(h)) end
      return nil
    end,
    Para  = rewrap_cites,
    Plain = rewrap_cites,
  }
  doc.blocks = result.blocks
  return doc
end
