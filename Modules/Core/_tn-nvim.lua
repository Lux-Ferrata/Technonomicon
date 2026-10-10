-- Technonomicon's colours in nvim: Tn-neovim's LazyVim and the rescue nvim
-- (Tn-server-nvim). Expects `B` (base16) and `P` (roles) from _palette.nix
-- just before it. mini.base16 draws the whole interface from B, so floats,
-- pickers and status lines match the desktop. Then the syntax is cut back to
-- Tonsky's set, the same as VSCodium's: comments yellow, strings green,
-- constants purple, definitions blue, punctuation grey, everything else
-- plain, and no bold or italic.
require("mini.base16").setup({ palette = B, use_cterm = true })

local function hl(name, spec) vim.api.nvim_set_hl(0, name, spec) end
local function each(names, spec)
  for _, name in ipairs(names) do hl(name, spec) end
end
-- fg laid over bg at strength a (diff backgrounds)
local function blend(fg, bg, a)
  local out = "#"
  for i = 2, 6, 2 do
    local f, b = tonumber(fg:sub(i, i + 1), 16), tonumber(bg:sub(i, i + 1), 16)
    out = out .. string.format("%02X", math.floor(f * a + b * (1 - a) + 0.5))
  end
  return out
end

-- ── syntax ───────────────────────────────────────────────────────────────
each({
  "Statement", "Conditional", "Repeat", "Label", "Keyword", "Exception",
  "PreProc", "Include", "Define", "Macro", "PreCondit", "Type",
  "StorageClass", "Structure", "Typedef", "Identifier", "Tag", "Debug",
  "@keyword", "@keyword.function", "@keyword.return", "@keyword.operator",
  "@keyword.import", "@keyword.conditional", "@keyword.repeat",
  "@keyword.exception", "@keyword.modifier", "@keyword.type",
  "@keyword.coroutine", "@keyword.directive",
  "@variable", "@variable.builtin", "@variable.parameter",
  "@variable.parameter.builtin", "@variable.member", "@property",
  "@function.call", "@function.method.call", "@function.builtin",
  "@function.macro", "@constructor", "@type", "@type.builtin",
  "@type.qualifier", "@module", "@module.builtin", "@attribute",
  "@attribute.builtin", "@label", "@tag", "@tag.attribute", "@tag.builtin",
  "@constant", "@constant.macro",   -- ALL_CAPS names are variables
}, { fg = P.plain })
each({
  "Delimiter", "Operator", "Special", "SpecialChar",
  "@operator", "@punctuation", "@punctuation.bracket",
  "@punctuation.delimiter", "@punctuation.special", "@tag.delimiter",
  "@string.escape", "@character.special",
}, { fg = P.punct })
each({
  "Comment", "SpecialComment", "Todo", "@comment", "@comment.documentation",
  "@string.documentation", "@comment.todo", "@comment.note",
  "@comment.warning", "@comment.error",
}, { fg = P.comment })
each({
  "String", "@string", "@string.regexp", "@string.special",
  "@string.special.path", "@string.special.url",
}, { fg = P.string })
each({
  "Constant", "Number", "Float", "Boolean", "Character",
  "@number", "@number.float", "@boolean", "@character",
  "@constant.builtin", "@string.special.symbol",
}, { fg = P.const })
each({
  "Function", "@function", "@function.method", "@type.definition",
  "@markup.heading", "@tn.def",   -- @tn.def: after/queries (Nix, Python)
}, { fg = P.def })
hl("Error", { fg = P.error })

-- Semantic tokens would repaint calls, types and variables on top: drop the
-- generic ones, keep declarations as definitions.
for _, name in ipairs(vim.fn.getcompletion("@lsp.type.", "highlight")) do
  hl(name, {})
end
each({
  "@lsp.typemod.function.declaration", "@lsp.typemod.method.declaration",
  "@lsp.typemod.class.declaration", "@lsp.typemod.type.declaration",
}, { fg = P.def })

-- ── interface ────────────────────────────────────────────────────────────
hl("LineNr", { fg = P.dim, bg = P.bg })
hl("CursorLineNr", { fg = P.plain, bg = P.linehl })
hl("CursorLine", { bg = P.linehl })
hl("CursorColumn", { bg = P.linehl })
hl("ColorColumn", { bg = P.surface })
hl("SignColumn", { bg = P.bg })
hl("FoldColumn", { fg = P.dim, bg = P.bg })
hl("Folded", { fg = P.dim, bg = P.surface })
hl("EndOfBuffer", { fg = P.bg })
each({ "NonText", "Whitespace", "SpecialKey" }, { fg = P.whitespace })
each({ "Visual", "VisualNOS" }, { bg = P.sel })
each({ "WinSeparator", "VertSplit" }, { fg = P.border, bg = P.bg })

hl("NormalFloat", { fg = P.plain, bg = P.surface })
hl("FloatBorder", { fg = P.border, bg = P.surface })
hl("FloatTitle", { fg = P.second, bg = P.surface })
hl("StatusLine", { fg = P.second, bg = P.surface })
hl("StatusLineNC", { fg = P.dim, bg = P.surface })
hl("TabLine", { fg = P.dim, bg = P.surface })
hl("TabLineFill", { bg = P.surface })
hl("WinBar", { fg = P.second, bg = P.bg })
hl("WinBarNC", { fg = P.dim, bg = P.bg })

-- The row being chosen: solid blue, dark text, as everywhere else. A set fg
-- on these wins over the row's own colours, so nothing vanishes into the blue.
local chosen = { fg = P.bg, bg = P.accent }
each({ "PmenuSel", "PmenuKindSel", "PmenuExtraSel", "TabLineSel",
       "BlinkCmpMenuSelection", "SnacksPickerListCursorLine" }, chosen)
hl("PmenuMatchSel", { fg = P.bg, bg = P.accent, underline = true })
hl("Pmenu", { fg = P.plain, bg = P.surface })
each({ "PmenuKind", "PmenuExtra", "BlinkCmpKind", "BlinkCmpLabelDetail",
       "BlinkCmpLabelDescription", "SnacksPickerDir" }, { fg = P.dim })
for _, name in ipairs(vim.fn.getcompletion("BlinkCmpKind", "highlight")) do
  hl(name, { fg = P.dim })   -- kind icons stay quiet
end
hl("PmenuSbar", { bg = P.surface })
hl("PmenuThumb", { bg = P.border })
each({ "PmenuMatch", "BlinkCmpLabelMatch", "SnacksPickerMatch" },
  { fg = P.accent, underline = true })
hl("BlinkCmpMenu", { link = "Pmenu" })
each({ "BlinkCmpMenuBorder", "BlinkCmpDocBorder", "SnacksPickerBorder" },
  { link = "FloatBorder" })
hl("BlinkCmpDoc", { link = "NormalFloat" })

hl("Search", { fg = P.bg, bg = P.search })
hl("Substitute", { fg = P.bg, bg = P.search })
each({ "IncSearch", "CurSearch" }, { fg = P.bg, bg = P.accent })
hl("MatchParen", { fg = P.search, underline = true })

hl("Title", { fg = P.def })
hl("Directory", { fg = P.def })
hl("ErrorMsg", { fg = P.error })
hl("WarningMsg", { fg = P.warn })
hl("MoreMsg", { fg = P.string })
hl("Question", { fg = P.def })
hl("ModeMsg", { fg = P.second })

for kind, col in pairs({ Error = P.error, Warn = P.warn, Info = P.info, Hint = P.hint, Ok = P.add }) do
  hl("Diagnostic" .. kind, { fg = col })
  hl("DiagnosticVirtualText" .. kind, { fg = col })
  hl("DiagnosticSign" .. kind, { fg = col, bg = P.bg })
  hl("DiagnosticFloating" .. kind, { fg = col })
  hl("DiagnosticUnderline" .. kind, { undercurl = true, sp = col })
end
hl("LspInlayHint", { fg = P.dim })   -- dim text, no box

each({ "GitSignsAdd", "MiniDiffSignAdd", "Added", "@diff.plus" }, { fg = P.add })
each({ "GitSignsChange", "MiniDiffSignChange", "Changed", "@diff.delta" }, { fg = P.change })
each({ "GitSignsDelete", "MiniDiffSignDelete", "Removed", "@diff.minus" }, { fg = P.del })
hl("DiffAdd", { bg = blend(P.add, P.bg, 0.18) })
hl("DiffDelete", { fg = P.del, bg = blend(P.del, P.bg, 0.16) })
hl("DiffChange", { bg = blend(P.change, P.bg, 0.12) })
hl("DiffText", { bg = blend(P.change, P.bg, 0.32) })

hl("SpellBad", { undercurl = true, sp = P.error })
hl("SpellCap", { undercurl = true, sp = P.warn })
each({ "SpellRare", "SpellLocal" }, { undercurl = true, sp = P.info })

each({ "SnacksIndent", "IblIndent" }, { fg = P.whitespace })
each({ "SnacksIndentScope", "IblScope" }, { fg = P.dim })
-- flash jumps: red tags with dark text, as in VSCodium
hl("FlashLabel", { fg = P.bg, bg = P.error })
hl("FlashMatch", { fg = P.info })
hl("FlashCurrent", { fg = P.search })
hl("FlashBackdrop", { fg = P.dim })
