-- Copy this file to domains_local.lua and fill in machine-specific values.
-- domains_local.lua is intentionally ignored by Git.
return {
  ssh_domains = {
    {
      name = "example",
      remote_address = "host.example.com:22",
      username = "your-user",
      multiplexing = "None",
      ssh_option = {
        identityfile = "~/.ssh/id_rsa",
      },
    },
  },
  unix_domains = {},
  wsl_domains = {},
}
