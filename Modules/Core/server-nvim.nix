{ inputs, ... }: {
  # Minimal "rescue" neovim for headless hosts: just enough to fix a config
  # over ssh. Real editing happens on Kvasir (Tn-neovim / LazyVim).
  flake.nixosModules.Tn-server-nvim = { pkgs, ... }: {

    programs.neovim = {
      enable        = true;
      defaultEditor = true;
      viAlias       = true;
      vimAlias      = true;

      configure = {
        packages.rescue.start = with pkgs.vimPlugins; [
          flash-nvim
          nord-nvim
        ];

        customLuaRC = ''
          vim.g.mapleader      = " "
          vim.opt.number         = true
          vim.opt.relativenumber = true
          vim.opt.cursorline     = true
          vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
          vim.opt.wrap      = true
          vim.opt.linebreak = true

          vim.g.nord_contrast = true
          vim.g.nord_italic   = true
          vim.g.nord_bold     = false
          require("nord").set()

          -- same `s` jump as LazyVim (no treesitter here, so no `S`)
          require("flash").setup()
          vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash" })

          -- `_` separates words, matching Tn-neovim / VSCodium
          vim.opt.iskeyword:remove("_")
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "*",
            callback = function()
              vim.opt_local.iskeyword:remove("_")
            end,
          })

          vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*",
            callback = function()
              local pos = vim.api.nvim_win_get_cursor(0)
              vim.cmd([[%s/\s\+$//e]])
              vim.api.nvim_win_set_cursor(0, pos)
            end,
          })

          vim.keymap.set("i", "<C-BS>", "<C-w>", { desc = "Delete word before cursor" })
          vim.keymap.set("i", "<C-h>", "<C-w>", { desc = "Delete word before cursor" })
        '';
      };
    };
  };
}
