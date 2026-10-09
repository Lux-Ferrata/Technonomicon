-- Tonsky/Alabaster-style syntax on top of nord.nvim, matching VSCodium's
-- tokenColorCustomizations (Tn-neovim): comments bright gold, strings,
-- constants and definitions coloured, everything else plain text, all on a
-- deeper-than-nord0 background so every colour is >= 8:1 (WCAG AAA). Loaded
-- after require("nord").set() by both LazyVim and the server rescue nvim.
local function nord_alabaster()
  local bg      = "#1E222A" -- deeper Nord night
  local plain   = "#ECEFF4" -- nord6
  local comment = "#FBC260" -- gold, nord13's hue deepened
  local string  = "#B5E689" -- nord14, saturated
  local const   = "#EBA2DE" -- nord15, saturated
  local def     = "#7BDAF4" -- nord8, saturated

  -- the text area and its margins on the deeper background; floats, status
  -- and tab lines keep nord.nvim's own shades
  for _, name in ipairs({ "SignColumn", "FoldColumn", "EndOfBuffer" }) do
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    hl.bg = bg
    vim.api.nvim_set_hl(0, name, hl)
  end
  vim.api.nvim_set_hl(0, "Normal", { fg = plain, bg = bg })
  vim.api.nvim_set_hl(0, "NormalNC", { fg = plain, bg = bg })
  vim.api.nvim_set_hl(0, "LineNr", { fg = "#7B88A1", bg = bg })
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = plain, bg = bg, bold = true })

  local groups = {
    [plain] = {
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
    [string] = {
      "String", "@string", "@string.escape", "@string.regexp",
      "@string.special",
    },
    [const] = {
      "Constant", "Number", "Float", "Boolean", "Character",
      "@number", "@number.float", "@boolean", "@character",
      "@constant.builtin",
    },
    [def] = {
      "@function", "@function.method", "@method", "@type.definition",
      "@function.macro", "@markup.heading",
      "@lsp.typemod.function.declaration", "@lsp.typemod.method.declaration",
      "@lsp.typemod.class.declaration", "@lsp.typemod.type.declaration",
    },
    [comment] = {
      "Comment", "SpecialComment", "@comment", "@comment.documentation",
      "@string.documentation",
    },
  }

  for fg, names in pairs(groups) do
    for _, name in ipairs(names) do
      vim.api.nvim_set_hl(0, name, { fg = fg })
    end
  end

  -- LSP semantic tokens would repaint variables, types and calls on top of
  -- treesitter; drop the generic ones (the declaration typemods above stay).
  for _, name in ipairs(vim.fn.getcompletion("@lsp.type.", "highlight")) do
    vim.api.nvim_set_hl(0, name, {})
  end
end

nord_alabaster()
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "nord",
  callback = nord_alabaster,
})
