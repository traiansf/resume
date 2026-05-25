-- Lua filter for processing [LONG]...[/LONG] markers
-- Usage: pandoc -L filter.lua -V short_version=true input.md -o output.pdf

local short_version = false

-- Get the short_version variable from document metadata
function Pandoc(doc)
  if doc.meta and doc.meta.short_version then
    short_version = pandoc.utils.stringify(doc.meta.short_version) == "true"
  end

  -- Process all blocks
  local result = {}
  local in_long_block = false

  for _, block in ipairs(doc.blocks) do
    if block.t == "Para" then
      local content = block.content
      local text = pandoc.utils.stringify(content)

      -- Check if this paragraph contains both [LONG] and [/LONG] markers
      if text:find("%[LONG%]") and text:find("%[/LONG%]") then
        -- Inline long block - extract content between markers
        if short_version then
          -- Remove everything between [LONG] and [/LONG]
          local cleaned = text:gsub("%[LONG%].*%[/LONG%]", "")
          if cleaned:gsub("%s", ""):len() > 0 then
            table.insert(result, pandoc.Para(cleaned))
          end
        else
          -- Keep everything but remove markers
          local cleaned = text:gsub("%[LONG%]", ""):gsub("%[/LONG%]", "")
          if cleaned:gsub("%s", ""):len() > 0 then
            table.insert(result, pandoc.Para(cleaned))
          end
        end
      elseif text:find("%[LONG%]") then
        in_long_block = true
        -- If short_version, skip this block; otherwise include it without the marker
        if not short_version then
          -- Remove the [LONG] marker itself
          local cleaned_text = text:gsub("%[LONG%]", "")
          if cleaned_text:gsub("%s", ""):len() > 0 then
            table.insert(result, pandoc.Para(cleaned_text))
          end
        end
      elseif text:find("%[/LONG%]") then
        in_long_block = false
        -- Remove the [/LONG] marker itself - don't add to result
      elseif in_long_block then
        -- We're inside a long block
        if not short_version then
          table.insert(result, block)
        end
        -- If short_version and in_long_block, skip this block
      else
        -- Normal block, not in a long section
        table.insert(result, block)
      end
    else
      -- For non-paragraph blocks, check if we're in a long section
      if not in_long_block then
        table.insert(result, block)
      elseif not short_version then
        table.insert(result, block)
      end
    end
  end

  doc.blocks = result
  return doc
end
