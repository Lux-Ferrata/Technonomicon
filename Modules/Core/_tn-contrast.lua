-- Technonomicon high contrast on top of nord.nvim (which supplies the
-- structure: plugin groups, lualine). Expects `P`, the palette from
-- _palette.nix, defined just before it. Black ground, white text, and
-- Alabaster-style syntax matching VSCodium's: comments dark orange,
-- strings green, constants red, definitions blue, everything else plain.
-- Loaded after require("nord").set() by both LazyVim and the server
-- rescue nvim.
local function tn_contrast()
  local hl = function(name, spec) vim.api.nvim_set_hl(0, name, spec) end

  -- the text area and its margins on black
  for _, name in ipairs({ "SignColumn", "FoldColumn", "EndOfBuffer" }) do
    local h = vim.api.nvim_get_hl(0, { name = name, link = false })
    h.bg = P.bg
    hl(name, h)
  end
  hl("Normal", { fg = P.plain, bg = P.bg })
  hl("NormalNC", { fg = P.plain, bg = P.bg })
  hl("LineNr", { fg = P.dim, bg = P.bg })
  hl("CursorLineNr", { fg = P.comment, bg = P.bg, bold = true })
  hl("CursorLine", { bg = P.panel })
  hl("ColorColumn", { bg = P.panel })
  hl("Visual", { bg = P.sel })
  hl("NonText", { fg = P.dim })
  hl("Whitespace", { fg = P.dim })

  -- floats, menus, status: one panel shade with blue edges
  hl("NormalFloat", { fg = P.plain, bg = P.panel })
  hl("FloatBorder", { fg = P.def, bg = P.panel })
  hl("FloatTitle", { fg = P.def, bg = P.panel, bold = true })
  hl("Pmenu", { fg = P.plain, bg = P.panel })
  hl("PmenuSel", { fg = P.bg, bg = P.def, bold = true })
  hl("PmenuSbar", { bg = P.sel })
  hl("PmenuThumb", { bg = P.dim })
  hl("StatusLine", { fg = P.plain, bg = P.panel })
  hl("StatusLineNC", { fg = P.dim, bg = P.panel })
  hl("WinSeparator", { fg = P.dim, bg = P.bg })
  hl("TabLine", { fg = P.dim, bg = P.panel })
  hl("TabLineSel", { fg = P.bg, bg = P.def, bold = true })
  hl("TabLineFill", { bg = P.panel })

  -- search and matches: solid colour, black text
  hl("Search", { fg = P.bg, bg = P.comment })
  hl("IncSearch", { fg = P.bg, bg = P.def })
  hl("CurSearch", { fg = P.bg, bg = P.def })
  hl("MatchParen", { fg = P.comment, bold = true, underline = true })

  -- messages, diagnostics, diffs
  hl("Title", { fg = P.def, bold = true })
  hl("Directory", { fg = P.def })
  hl("ErrorMsg", { fg = P.const, bold = true })
  hl("WarningMsg", { fg = P.warn })
  hl("DiagnosticError", { fg = P.const })
  hl("DiagnosticWarn", { fg = P.warn })
  hl("DiagnosticInfo", { fg = P.info })
  hl("DiagnosticHint", { fg = P.string })
  hl("DiagnosticUnderlineError", { undercurl = true, sp = P.const })
  hl("DiagnosticUnderlineWarn", { undercurl = true, sp = P.warn })
  hl("DiagnosticUnderlineInfo", { undercurl = true, sp = P.info })
  hl("DiagnosticUnderlineHint", { undercurl = true, sp = P.string })
  hl("DiffAdd", { fg = P.string })
  hl("DiffDelete", { fg = P.const })
  hl("DiffChange", { fg = P.def })
  hl("DiffText", { fg = P.bg, bg = P.def })
  hl("Added", { fg = P.string })
  hl("Removed", { fg = P.const })
  hl("Changed", { fg = P.def })

  local groups = {
    [P.plain] = {
      "Statement", "Conditional", "Repeat", "Label", "Operator", "Keyword",
      "Exception", "PreProc", "Include", "Define", "Macro", "PreCondit",
      "Type", "StorageClass", "Structure", "Typedef", "Identifier",
      "Function", "Special", "SpecialChar", "Delimiter", "Tag",
      "@keyword", "@keyword.function", "@keyword.return", "@keyword.operator",
      "@keyword.import", "@keyword.conditional", "@keyword.repeat",
      "@keyword.exception", "@keyword.modifier", "@keyword.type",
      "@operator", "@punctuation", "@punctuation.bracket",
      "@punctuation.delimiter", "@punctuation.special",
      "@variable", "@variable.builtin", "@variable.parameter",
      "@variable.member", "@property", "@field", "@parameter",
      "@function.call", "@function.method.call", "@method.call",
      "@function.builtin", "@constructor", "@type", "@type.builtin",
      "@module", "@namespace", "@attribute", "@label", "@tag",
      "@tag.attribute", "@tag.delimiter", "@constant",
    },
    [P.string] = {
      "String", "@string", "@string.escape", "@string.regexp",
      "@string.special",
    },
    [P.const] = {
      "Constant", "Number", "Float", "Boolean", "Character",
      "@number", "@number.float", "@boolean", "@character",
      "@constant.builtin",
    },
    [P.def] = {
      "@function", "@function.method", "@method", "@type.definition",
      "@function.macro", "@markup.heading",
      "@lsp.typemod.function.declaration", "@lsp.typemod.method.declaration",
      "@lsp.typemod.class.declaration", "@lsp.typemod.type.declaration",
    },
    [P.comment] = {
      "Comment", "SpecialComment", "@comment", "@comment.documentation",
      "@string.documentation",
    },
  }

  for fg, names in pairs(groups) do
    for _, name in ipairs(names) do
      hl(name, { fg = fg })
    end
  end

  -- LSP semantic tokens would repaint variables, types and calls on top of
  -- treesitter; drop the generic ones (the declaration typemods above stay).
  for _, name in ipairs(vim.fn.getcompletion("@lsp.type.", "highlight")) do
    hl(name, {})
  end
end

tn_contrast()
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "nord",
  callback = tn_contrast,
})
