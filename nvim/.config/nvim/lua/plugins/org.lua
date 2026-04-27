local org_root = "~/Dropbox/Vaults/gible"

return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    keys = {
      { "<leader>oc", '<cmd>lua require("orgmode").action("capture.prompt")<cr>', desc = "Org Capture" },
      { "<leader>oa", '<cmd>lua require("orgmode").action("agenda.prompt")<cr>', desc = "Org Agenda" },
    },
    config = function()
      require("orgmode").setup({
        -- top-level files + dailies + project nodes (which carry their own TODOs);
        -- thoughts/ excluded since it's PKM, not tasks
        org_agenda_files = {
          org_root .. "/*.org",
          org_root .. "/dailies/**/*.org",
          org_root .. "/projects/**/*.org",
        },
        org_default_notes_file = org_root .. "/inbox.org",

        org_todo_keywords = {
          "TODO",
          "IN-PROGRESS",
          "WAITING",
          "|",
          "DONE",
          "CANCELLED",
        },

        org_todo_keyword_faces = {
          TODO = ":foreground red :weight bold",
          ["IN-PROGRESS"] = ":foreground orange :weight bold",
          WAITING = ":foreground yellow",
          DONE = ":foreground green :strike-through t",
          CANCELLED = ":foreground gray :strike-through t",
        },

        org_agenda_span = "week",
        org_deadline_warning_days = 3,

        -- custom agenda views; accessible from the <leader>oa picker
        org_agenda_custom_commands = {
          r = {
            description = "Refile queue",
            types = {
              {
                type = "tags",
                match = "refile",
                org_agenda_overriding_header = "Items tagged :refile: (process me)",
              },
            },
          },
        },

        org_capture_templates = {
          t = {
            description = "Task",
            template = "* TODO %?\n  SCHEDULED: %t",
            target = org_root .. "/todo.org",
          },
          i = {
            description = "Inbox / Quick note",
            -- :refile: tag comes from #+FILETAGS in inbox.org, so headings stay clean
            template = "* %?\n  %U",
            target = org_root .. "/inbox.org",
          },
        },
      })
    end,
  },

  {
    "hamidi-dev/org-super-agenda.nvim",
    dependencies = {
      "nvim-orgmode/orgmode",
      { "lukas-reineke/headlines.nvim", config = true },
    },
    config = function()
      require("org-super-agenda").setup({
        org_files = {},
        org_directories = { org_root },
        exclude_directories = {
          org_root .. "/notes",
        },
        todo_states = {
          { name = "TODO", color = "#FF5555", strike_through = false },
          { name = "IN-PROGRESS", color = "#FFAA00", strike_through = false },
          { name = "WAITING", color = "#BD93F9", strike_through = false },
          { name = "DONE", color = "#50FA7B", strike_through = true },
          { name = "CANCELLED", color = "#666666", strike_through = true },
        },
      })
    end,
  },

  {
    "chipsenkbeil/org-roam.nvim",
    dependencies = { "nvim-orgmode/orgmode" },
    keys = {
      { "<leader>of", '<cmd>lua require("org-roam").api.find_node()<cr>', desc = "Roam Find Node" },
      { "<leader>oi", '<cmd>lua require("org-roam").api.insert_node()<cr>', desc = "Roam Insert Link" },
      { "<leader>on", '<cmd>lua require("org-roam").api.capture_node()<cr>', desc = "Roam Capture Node" },
      { "<leader>ob", '<cmd>lua require("org-roam").api.toggle_roam_buffer()<cr>', desc = "Roam Backlinks Buffer" },
      { "<leader>od", '<cmd>lua require("org-roam").ext.dailies.capture_today()<cr>', desc = "Daily: Capture Today" },
      { "<leader>oD", '<cmd>lua require("org-roam").ext.dailies.goto_today()<cr>', desc = "Daily: Goto Today" },
      { "<leader>oy", '<cmd>lua require("org-roam").ext.dailies.goto_yesterday()<cr>', desc = "Daily: Goto Yesterday" },
      { "<leader>ot", '<cmd>lua require("org-roam").ext.dailies.goto_tomorrow()<cr>', desc = "Daily: Goto Tomorrow" },
    },
    config = function()
      require("org-roam").setup({
        directory = org_root,
        -- disable plugin's built-in <Leader>n* bindings; we set our own under <leader>o
        bindings = false,
        -- fleeting notes live in inbox.org via orgmode capture (<leader>oc i);
        -- roam nodes are for the longer-lived PKM layers
        templates = {
          e = {
            description = "evergreen",
            template = "%?",
            target = "evergreen/%<%Y%m%d%H%M%S>-%[slug].org",
          },
          l = {
            description = "literature",
            template = "* Source\n\n* Summary\n%?\n\n* Key ideas\n\n* Related\n",
            target = "literature/%<%Y%m%d%H%M%S>-%[slug].org",
          },
          p = {
            description = "project",
            template = "* Goals\n%?\n\n* Tasks\n** TODO \n\n* Notes\n",
            target = "projects/%<%Y%m%d%H%M%S>-%[slug].org",
          },
        },
        extensions = {
          dailies = {
            directory = "dailies",
          },
        },
      })
    end,
  },

  {
    "nvim-orgmode/telescope-orgmode.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-orgmode/orgmode",
    },
    keys = {
      { "<leader>oh", "<cmd>Telescope orgmode search_headings<cr>", desc = "Search Org Headings" },
      { "<leader>ol", "<cmd>Telescope orgmode search_links<cr>", desc = "Search Org Links" },
    },
    config = function()
      require("telescope").load_extension("orgmode")
    end,
  },

  {
    "nvim-orgmode/org-bullets.nvim",
    ft = { "org" },
    config = function()
      require("org-bullets").setup()
    end,
  },
}
