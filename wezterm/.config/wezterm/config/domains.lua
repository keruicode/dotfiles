local wezterm = require("wezterm")

local domains = {
  ssh_domains = {},
  unix_domains = {},
  wsl_domains = {},
}

local ok, local_domains = pcall(require, "config.domains_local")
if not ok then
  local missing = "module 'config.domains_local' not found"
  if not tostring(local_domains):find(missing, 1, true) then
    wezterm.log_error("Unable to load local domains: " .. tostring(local_domains))
  end
  return domains
end

if type(local_domains) ~= "table" then
  wezterm.log_error("config.domains_local must return a table")
  return domains
end

for name, value in pairs(local_domains) do
  domains[name] = value
end

return domains
