-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- leader key
vim.g.mapleader = " "

-- basics
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"

-- ripgrep as :grep backend (fallback workflow)
vim.opt.grepprg = "rg --vimgrep"
vim.opt.grepformat = "%f:%l:%c:%m"

require("lazy").setup({
  -- File tree
  { "preservim/nerdtree" },
  { "ryanoasis/vim-devicons" },
  { "Xuyuanp/nerdtree-git-plugin" },

  -- Treesitter (syntax/indent)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "python", "cpp", "javascript", "bash" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Terminal toggle
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 20,
        open_mapping = [[<C-\>]], -- You can change this to any keymap
        direction = "horizontal", -- Changed from "float" to "horizontal"
        terminal_mappings = true,
      })
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" }, { name = "path" },
        }),
      })
    end,
  },

  -- LSP
  { "neovim/nvim-lspconfig" },

  -- Telescope (optional)
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files (Telescope)" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Live grep (Telescope)" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Buffers (Telescope)" })
    end,
  },

  -- FZF core + fzf.vim (interactive :Rg)
  {
    "junegunn/fzf",
    build = "./install --bin", -- build the fzf binary locally
  },
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
    config = function()
      -- FZF window + preview
      vim.g.fzf_layout = { window = { width = 0.9, height = 0.8 } }
      vim.g.fzf_preview_window = { "right:60%", "ctrl-/" }

      -- Use ripgrep with hidden files but ignore .git when you run :Rg
      -- (you can still pass extra args: e.g. :Rg --type=py foo)
      vim.keymap.set("n", "<leader>/", ":Rg --hidden -g !.git/ ",
        { desc = "Ripgrep (FZF)", silent = false })

      -- Extra handy pickers
      vim.keymap.set("n", "<leader>sf", ":Files<CR>",    { desc = "Files (FZF)" })
      vim.keymap.set("n", "<leader>sb", ":Buffers<CR>", { desc = "Buffers (FZF)" })
      vim.keymap.set("n", "<C-p>", ":Files<CR>", { desc = "Find files (FZF)" })
      
      -- New keymap for recursive content search (project-wide)
      vim.keymap.set("n", "<C-l>", ":Rg<CR>", { desc = "Project-wide grep (FZF)" })

      -- Keymap for local file search
      vim.keymap.set("n", "<C-f>", ":silent !Rg -n --color=always <C-r><C-w> %<CR>", { desc = "Local file grep", silent = false })


      -- Safe lowercase alias: turn `:rg` into `:Rg` on the cmdline (no custom command!)
      vim.cmd([[
        cnoreabbrev <expr> rg (getcmdtype() == ':' && getcmdline() =~# '^\s*rg\>') ? 'Rg' : 'rg'
      ]])
    end,
  },

  -- Seamless navigation between Neovim splits AND tmux panes
  {
    "numToStr/Navigator.nvim",
    config = function()
      require("Navigator").setup()
    end,
  },

  -- GitHub Copilot
  { "github/copilot.vim" },

  -- Tabline/Buffer Management
  {
    "akinsho/bufferline.nvim",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({}) -- Added this line to initialize the plugin
      vim.keymap.set("n", "<S-h>", ":BufferLineCyclePrev<CR>", { silent = true, desc = "Previous Tab" })
      vim.keymap.set("n", "<S-l>", ":BufferLineCycleNext<CR>", { silent = true, desc = "Next Tab" })
    end,
  }
})

-- NERDTree: toggle and auto-open when no file is given
vim.keymap.set("n", "<C-n>", ":NERDTreeToggle<CR>", { silent = true })
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 then vim.cmd("NERDTree") end
  end
})

-- Example LSP: Python (requires `pip install pyright`)
local lspconfig = require("lspconfig")
lspconfig.pyright.setup({})

-- === Ctrl-b + Arrow: move between splits & tmux panes (Normal + Terminal) ===
local function map(modes, lhs, rhs)
  vim.keymap.set(modes, lhs, rhs, { silent = true, noremap = true })
end

-- map({ "n", "t" }, "<C-b><Left>",  "<Cmd>NavigatorLeft<CR>")
-- map({ "n", "t" }, "<C-b><Down>",  "<Cmd>NavigatorDown<CR>")
-- map({ "n", "t" }, "<C-b><Up>",    "<Cmd>NavigatorUp<CR>")
-- map({ "n", "t" }, "<C-b><Right>", "<Cmd>NavigatorRight<CR>")
