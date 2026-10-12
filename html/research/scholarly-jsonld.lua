-- Emit schema.org ScholarlyArticle / Chapter JSON-LD for research pages,
-- built from the same frontmatter that feeds the Google Scholar meta tags
-- (title, author, date, description, doi, citation.*).

local SITE = "https://antoinevernet.com"
local ME_ORCID = "0000-0002-7546-9829"

local function str(x)
  if x == nil then return nil end
  local s = pandoc.utils.stringify(x)
  if s == "" then return nil end
  return s
end

local function json_escape(s)
  s = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"'
    elseif c == '\\' then return '\\\\'
    elseif c == '\n' then return '\\n'
    else return string.format('\\u%04x', c:byte()) end
  end)
  -- keep "</script>" from closing the tag
  return (s:gsub('<', '\\u003c'))
end

local encode
local function is_array(t)
  return type(t) == "table" and #t > 0 and next(t, #t) == nil
end
encode = function(v)
  if type(v) == "string" then return '"' .. json_escape(v) .. '"'
  elseif type(v) == "number" then return tostring(v)
  elseif is_array(v) then
    local parts = {}
    for _, x in ipairs(v) do parts[#parts + 1] = encode(x) end
    return "[" .. table.concat(parts, ", ") .. "]"
  else
    -- fixed key order for readable, stable output
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      local ra, rb = a:sub(1, 1) == "@", b:sub(1, 1) == "@"
      if ra ~= rb then return ra end
      return a < b
    end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = encode(k) .. ": " .. encode(v[k]) end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
end

-- Quarto normalises `author` into `authors` (name.literal, orcid,
-- affiliations[{ref}]) plus a top-level `affiliations` list.
local function person(a, affs)
  local name = a.name and (str(a.name.literal) or str(a.name))
  if not name then return nil end
  local orcid = str(a.orcid)
  local p = { ["@type"] = (orcid or not name:match("Collaboration")) and "Person" or "Organization", name = name }
  if orcid == ME_ORCID then
    p["@id"] = SITE .. "/#person"
  end
  if orcid then p.sameAs = "https://orcid.org/" .. orcid end
  for _, ref in ipairs(a.affiliations or {}) do
    local aff = affs[str(ref.ref) or str(ref.id) or ""]
    if aff then p.affiliation = { ["@type"] = "Organization", name = aff } end
  end
  return p
end

-- `date` arrives already formatted ("March 1, 2024"); turn it back into ISO.
local MONTHS = { January = 1, February = 2, March = 3, April = 4, May = 5, June = 6,
  July = 7, August = 8, September = 9, October = 10, November = 11, December = 12 }
local function iso_date(s)
  if not s then return nil end
  if s:match("^%d%d%d%d") then return s end
  local m, d, y = s:match("^(%a+) (%d+), (%d%d%d%d)$")
  if m and MONTHS[m] then return string.format("%s-%02d-%02d", y, MONTHS[m], tonumber(d)) end
  return nil
end

function Meta(meta)
  local title = str(meta.title)
  -- only paper pages (they carry pub-info), not the /research/ listing
  if not title or not meta["pub-info"] then return nil end

  local cit = meta.citation
  if type(cit) ~= "table" then cit = {} end
  local ctype = str(cit.type)
  local is_chapter = ctype == "chapter"

  local doc = {
    ["@context"] = "https://schema.org",
    ["@type"] = is_chapter and "Chapter" or "ScholarlyArticle",
    name = title,
    headline = title,
  }

  -- page URL: research/x/y/index.qmd -> https://site/research/x/y/
  local rel = pandoc.path.make_relative(quarto.doc.input_file, quarto.project.directory)
  doc.url = SITE .. "/" .. rel:gsub("index%.qmd$", "")

  local affs = {}
  for _, af in ipairs(meta.affiliations or {}) do
    if str(af.id) then affs[str(af.id)] = str(af.name) end
  end
  local authors = {}
  for _, a in ipairs(meta.authors or {}) do
    local p = person(a, affs)
    if p then authors[#authors + 1] = p end
  end
  if #authors > 0 then doc.author = authors end

  local issued = type(cit.issued) == "table" and str(cit.issued["iso-8601"]) or str(cit.issued)
  local date = iso_date(issued) or iso_date(str(meta.date))
  if date then doc.datePublished = date end

  -- publication language (citation.language); the pages themselves are in English
  doc.inLanguage = str(cit.language) or "en"

  local desc = str(meta.description)
  if desc then doc.description = desc end

  local doi = str(meta.doi) or str(cit.doi)
  if doi then
    doc.sameAs = "https://doi.org/" .. doi
    doc.identifier = { ["@type"] = "PropertyValue", propertyID = "DOI", value = doi }
  end

  local keywords = {}
  for _, c in ipairs(meta.categories or {}) do keywords[#keywords + 1] = str(c) end
  if #keywords > 0 then doc.keywords = keywords end

  local container = str(cit["container-title"])
  local publisher = str(cit.publisher)
  local pub = publisher and { ["@type"] = "Organization", name = publisher } or nil

  if container then
    if is_chapter then
      local book = { ["@type"] = "Book", name = container }
      if str(cit.isbn) then book.isbn = str(cit.isbn) end
      if pub then book.publisher = pub end
      local editors = cit.editor
      if editors then
        if pandoc.utils.type(editors) ~= "List" then editors = { editors } end
        local eds = {}
        for _, e in ipairs(editors) do eds[#eds + 1] = { ["@type"] = "Person", name = str(e) } end
        book.editor = eds
      end
      local series = str(cit["collection-title"])
      if series then
        book.isPartOf = { ["@type"] = "BookSeries", name = series }
        if str(cit.volume) then book.volumeNumber = str(cit.volume) end
      end
      doc.isPartOf = book
    else
      local periodical = { ["@type"] = "Periodical", name = container }
      if str(cit.issn) then periodical.issn = str(cit.issn) end
      if pub then periodical.publisher = pub end
      local part = periodical
      if str(cit.volume) then
        part = { ["@type"] = "PublicationVolume", volumeNumber = str(cit.volume), isPartOf = part }
      end
      if str(cit.issue) then
        part = { ["@type"] = "PublicationIssue", issueNumber = str(cit.issue), isPartOf = part }
      end
      doc.isPartOf = part
    end
  end
  if pub then doc.publisher = pub end

  local page = str(cit.page)
  if page then
    doc.pagination = page
    local first, last = page:match("^(%w+)%-(%w+)$")
    if first then doc.pageStart, doc.pageEnd = first, last end
  end

  local pdf = str(cit["pdf-url"])
  if pdf then
    doc.encoding = { ["@type"] = "MediaObject", encodingFormat = "application/pdf", contentUrl = pdf }
  end

  quarto.doc.include_text("in-header",
    '<script type="application/ld+json">\n' .. encode(doc) .. '\n</script>')
  return nil
end
