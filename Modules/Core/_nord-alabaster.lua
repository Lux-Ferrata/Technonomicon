-- Tonsky/Alabaster-style syntax on top of nord.nvim, matching VSCodium's
-- tokenColorCustomizations (Tn-neovim): comments bright (nord13), strings,
-- constants and definitions coloured, everything else plain text. Loaded
-- after require("nord").set() by both LazyVim and the server rescue nvim.
local function nord_alabaster()
  local plain   = "#D8DEE9" -- nord4
  local comment = "#EBCB8B" -- nord13
  local string  = "#A3BE8C" -- nord14
  local const   = "#B48EAD" -- nord15
  local def     = "#88C0D0" -- nord8

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
